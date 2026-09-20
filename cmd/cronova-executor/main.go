// Command cronova-executor is the long-lived task executor. The scheduler
// dispatches tasks to it over a local gRPC socket; because it is a separate
// process, a scheduler restart does not kill running tasks — the scheduler
// re-attaches by probing them (see docs/ARCHITECTURE.md §8–§9).
package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"

	"github.com/zoyluo/cronova/internal/executor"
	pb "github.com/zoyluo/cronova/proto/cronova/executor/v1"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
)

func main() {
	sock := flag.String("sock", defaultSocketPath(), "local executor endpoint (Unix socket on non-Windows; 127.0.0.1:port on Windows)")
	listenTCP := flag.String("listen-tcp", "", "additionally serve on this TCP address (host:port) under MANDATORY mutual TLS — for a scheduler on another machine")
	tlsCert := flag.String("tls-cert", "", "PEM certificate for -listen-tcp (required with it)")
	tlsKey := flag.String("tls-key", "", "PEM private key for -listen-tcp (required with it)")
	tlsCA := flag.String("tls-ca", "", "PEM CA that signed the SCHEDULER's client certificate (required with -listen-tcp)")
	stateDir := flag.String("state-dir", "", "persist attempt state here so restarts re-adopt running tasks (default: <socket dir>/state; \"none\" disables)")
	flag.Parse()
	if err := run(*sock, *listenTCP, *tlsCert, *tlsKey, *tlsCA, *stateDir); err != nil {
		log.Fatalf("cronova-executor: %v", err)
	}
}

func run(sock, listenTCP, tlsCert, tlsKey, tlsCA, stateDir string) error {
	lis, cleanup, err := listenExecutorSocket(sock)
	if err != nil {
		return err
	}
	defer lis.Close()
	defer cleanup()

	switch stateDir {
	case "":
		stateDir = filepath.Join(filepath.Dir(sock), "state")
	case "none":
		stateDir = ""
	}
	runner, err := executor.NewRunnerWithState(stateDir)
	if err != nil {
		return err
	}
	if stateDir != "" {
		if adopted, finished := runner.RecoverState(); adopted+finished > 0 {
			log.Printf("cronova-executor: recovered attempt state — %d running task(s) re-adopted, %d finished result(s) restored", adopted, finished)
		}
	}
	srv := grpc.NewServer()
	pb.RegisterExecutorServer(srv, executor.NewGRPCServer(runner))
	healthSrv := health.NewServer()
	healthSrv.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(srv, healthSrv)

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	go func() {
		<-ctx.Done()
		log.Println("cronova-executor shutting down")
		healthSrv.Shutdown()
		srv.GracefulStop()
	}()

	// Optional TCP listener for a remote scheduler: mTLS is not negotiable —
	// this endpoint executes arbitrary commands, so both sides must prove
	// identity. Tasks run on THIS host (logs land here; project attach needs a
	// shared filesystem, which the runner reports explicitly).
	if listenTCP != "" {
		tcpLis, err := listenExecutorTCP(listenTCP, tlsCert, tlsKey, tlsCA)
		if err != nil {
			return err
		}
		defer tcpLis.Close()
		go func() {
			log.Printf("cronova-executor listening on tcp://%s (mTLS)", listenTCP)
			if serr := srv.Serve(tcpLis); serr != nil && !errors.Is(serr, grpc.ErrServerStopped) {
				log.Printf("cronova-executor: tcp listener error: %v", serr)
			}
		}()
	}

	log.Printf("cronova-executor listening on local endpoint %s", sock)
	err = srv.Serve(lis)
	// After GracefulStop: with state persistence, tasks KEEP RUNNING and the
	// restarted executor re-adopts them (upgrades don't fail in-flight work);
	// without it, kill the process groups so they are not left as orphans.
	runner.Shutdown()
	if err != nil && !errors.Is(err, grpc.ErrServerStopped) {
		return err
	}
	return nil
}

// listenExecutorTCP builds the mutually-authenticated TCP listener: the
// executor presents cert/key, and ONLY clients bearing a certificate signed by
// ca may connect (RequireAndVerifyClientCert) — there is no plaintext mode.
func listenExecutorTCP(addr, certFile, keyFile, caFile string) (net.Listener, error) {
	if certFile == "" || keyFile == "" || caFile == "" {
		return nil, fmt.Errorf("-listen-tcp requires -tls-cert, -tls-key and -tls-ca (mutual TLS is mandatory)")
	}
	cert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		return nil, fmt.Errorf("load server cert: %w", err)
	}
	caPEM, err := os.ReadFile(caFile)
	if err != nil {
		return nil, fmt.Errorf("read ca: %w", err)
	}
	pool := x509.NewCertPool()
	if !pool.AppendCertsFromPEM(caPEM) {
		return nil, fmt.Errorf("no certificates in %s", caFile)
	}
	inner, err := net.Listen("tcp", addr)
	if err != nil {
		return nil, err
	}
	return tls.NewListener(inner, &tls.Config{
		Certificates: []tls.Certificate{cert},
		ClientAuth:   tls.RequireAndVerifyClientCert,
		ClientCAs:    pool,
		MinVersion:   tls.VersionTLS13,
		NextProtos:   []string{"h2"}, // gRPC requires ALPN on TLS listeners
	}), nil
}
