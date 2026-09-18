"use strict";

const $ = (id) => document.getElementById(id);
const main = $("main");

let view = "dags";       // dags | dag | task | run | pools | graph | workers | …
let activeDag = null;
let currentRun = null;
let filter = "all";
let query = "";
let overviewCache = null;
let authUser = null; // {username, role, auth} when signed in; null before auth resolves
let logES = null;
// language: a ?lang=pl|en query param (deep-linkable / shareable) wins, then the
// saved preference, then Polish.
const _urlLang = new URLSearchParams(location.search).get("lang");
let lang = (_urlLang === "pl" || _urlLang === "en") ? _urlLang : (localStorage.getItem("cnv_lang") || "pl");
let theme = localStorage.getItem("cnv_theme") || "dark";
// uiMode: "novice" | "expert". A saved preference wins; otherwise resolveMode()
// infers a default from the instance (empty => novice onboarding, has DAGs =>
// expert, so existing users never get their console flipped under them). Only an
// explicit toggle click persists — the inferred default stays adaptive.
let uiMode = null;
const nvMode = () => uiMode === "novice";
const DOCS_URL = "https://zoyluoblue.github.io/cronova/";

// D: in-memory editable spec for the active DAG operation page (immediate-save).
let D = null;
// ND: transient state for the minimal new-DAG modal.
let ND = null;
// SCHED: binding for the shared schedule UI {state, idp, host, onChange}.
let SCHED = null;
// coachDag: dag_id just created from a starter template -> show a one-time
// "template ready, hit ▶" ribbon on its operation page (session-only).
let coachDag = null;

// ---- i18n ----
const DICT = {
  pl: {
    workspace: "Przestrzeń robocza", nav_dags: "Przepływy pracy", newdag: "+ Nowy przepływ",
    f_all: "Wszystkie", f_running: "Uruchomione", f_failed: "Nieudane", f_paused: "Wstrzymane",
    dags_sub: "Kliknij nazwę, aby zobaczyć historię i strukturę; przełącznik po lewej wstrzymuje / wznawia harmonogram.",
    ov_fail_title: (id) => `${id}: ostatnie uruchomienie nie powiodło się`, ov_fail_more: (n) => `${n} kolejnych nieudanych`,
    ov_rest_ok: (n) => `pozostałe ${n} są zdrowe`, ov_all_ok: "Wszystkie przepływy pracy zdrowe", ov_last_run: (w) => `ostatnie uruchomienie ${w}`,
    ov_running: "Uruchomione", ov_running_tip: "Aktualnie wykonywane uruchomienia", ov_rate: "Ostatnia skuteczność", ov_go: "Zbadaj →",
    hlp_dag: '<b>Przepływ pracy (DAG)</b> = zadania uruchamiane w kolejności zależności plus reguła określająca kiedy uruchomić. <span class="eg">np. codziennie o 2:00 — pobierz → przekształć → załaduj.</span>',
    hlp_toggle: "<b>Przełącznik harmonogramu.</b> Wyłączony = brak automatycznych uruchomień (ręczne wciąż działa); historia jest zachowana i można włączyć w każdej chwili.",
    hlp_spark: 'Każdy słupek to jedno uruchomienie: <b class="ok">zielony</b>=sukces, <b class="bad">czerwony</b>=błąd, <b class="run">niebieski</b>=trwa; wyższy=wolniejszy. Najedź dla szczegółów.',
    hlp_next: "Następne automatyczne uruchomienie według harmonogramu. „gotowe” = oczekiwanie na wolny slot.",
    hlp_rate: "Udział ostatnich uruchomień, które zakończyły się sukcesem (do 14 na przepływ; pominięcia i anulowania się nie liczą).",
    toggle_tip_on: "Włączone — kliknij, aby wstrzymać harmonogram", toggle_tip_off: "Wstrzymane — kliknij, aby wznowić harmonogram",
    btn_run_word: "Uruchom", run_now_tip: "Uruchom raz teraz ręcznie — nie wpływa na harmonogram",
    day_today: "dziś", day_yesterday: "wczoraj",
    h_dag: "PRZEPŁYW", h_spark: "OSTATNIE 14", h_pool: "POOL", h_next: "NASTĘPNE",
    no_match: "Brak pasujących przepływów", no_match_filter: "Brak przepływów w tym filtrze", no_dags_title: "Brak przepływów", no_dags_sub: "Utwórz pierwszy przepływ, aby rozpocząć planowanie zadań.", trigger: "Wyzwól", manual_trigger: "tylko ręcznie",
    back_dags: "← Przepływy pracy", run_word: "uruchomienie", sub_manual: "tylko ręcznie", max_active: "maks. aktywnych",
    run_progress: "Postęp",
    sec_graph: "Graf zależności", sec_structure: "Struktura", sec_runs: "Historia uruchomień", sec_instances: "Instancje zadań",
    g_timeline: "Oś czasu", g_never_ran: "nie uruchomiono", run_no_tasks: "Brak jeszcze instancji zadań dla tego uruchomienia", run_done_ok: "Uruchomienie zakończone sukcesem", run_done_fail: "Uruchomienie nie powiodło się", run_done_timeout: "Przekroczono czas uruchomienia",
    run_cancel: "Anuluj uruchomienie", run_retry: "Ponów nieudane", task_retry: "Ponów", run_cancelled_toast: "Uruchomienie anulowane", run_retried_toast: "Ponownie zakolejkowano",
    task_mark: "Oznacz stan", run_mark: "Oznacz uruchomienie", mark_skip: "Pomiń", mark_done_toast: "Oznaczono",
    mark_task_title: (id) => `Oznacz zadanie „${id}” jako?`, mark_task_body: "Ręcznie nadpisz stan zadania. Działające zadanie zostanie najpierw zatrzymane; oznaczenie sukcesu/pominięcia odblokowuje zależne zadania.",
    mark_run_title: (id) => `Oznacz uruchomienie „${id}” jako?`, mark_run_body: "Nadpisz zapisany wynik zakończonego uruchomienia (zadania bez zmian). Oznaczenie sukcesu wywoła wyzwalacze zależnych przepływów.",
    confirm_cancel_title: (id) => `Anulować uruchomienie „${id}”?`, confirm_cancel_body: "Działające zadania zostaną zabite.", th_act: "Akcje",
    confirm_retry_title: (id) => `Ponowić „${id}”?`, confirm_retry_body: "To zadanie i wszystkie jego zależne zostaną zresetowane i uruchomione ponownie.",
    copied: "Skopiowano", copy_fail: "Kopiowanie nie powiodło się — zaznacz tekst ręcznie", copy_hint: "Kliknij, aby skopiować", search_ph: "Szukaj przepływów…", jump_open: "Otwórz", jump_none: "Brak pasującego przepływu",
    gz_in: "Powiększ", gz_out: "Pomniejsz", gz_fit: "Dopasuj", gz_hint: "Przeciągnij, aby przesunąć · Ctrl/⌘ + kółko, aby przybliżyć",
    login_title: "Zaloguj się do cronova", login_sub: "Wprowadź dane logowania", login_user: "Użytkownik", login_pass: "Hasło", login_btn: "Zaloguj", login_bad: "Nieprawidłowy użytkownik lub hasło", logout: "Wyloguj", sess_expired: "Sesja wygasła — zaloguj się ponownie", role_admin: "Administrator", role_viewer: "Podgląd",
    tab_runs: "Uruchomienia", tab_structure: "Struktura", tab_settings: "Ustawienia",
    dh_last: "Ostatnie uruchomienie", dh_next: "Harmonogram", dh_rate: "Skuteczność", dh_never: "Brak uruchomień", dh_norate: "—",
    set_done: "Gotowe", set_edit: "Edytuj", set_none: "Brak", set_sched: "Harmonogram", set_max: "Maks. aktywnych", set_retries: "Domyślne ponowienia", set_deps: "Nadrzędne przepływy",
    set_deps_hint: "Wyzwalane automatycznie po sukcesie tych przepływów", set_no_deps_avail: "Brak innych dostępnych przepływów",
    set_notify: "Powiadomienia", set_notify_hint: "Wyślij JSON webhook po zakończeniu uruchomienia (kompatybilne ze Slack/Feishu/Discord) lub odwołaj się do grupy alertów, aby powiadomić wiele kanałów naraz", notify_failure: "Błąd", notify_success: "Sukces", notify_off: "Nie wybrano zdarzeń", notify_need_url: "Najpierw podaj URL webhook lub wybierz grupę alertów, potem zaznacz zdarzenia", err_notify_url: "URL powiadomienia musi zaczynać się od http://, https:// lub mailto:",
    nf_label: "Format wiadomości", nf_hint: "raw = pełne JSON; pozostałe opakowują podsumowanie w formacie danego kanału; email dla celów mailto:", nf_feishu: "Feishu", nf_dingtalk: "DingTalk", nf_email: "Email",
    set_group: "Grupa alertów", ag_group_none: "Bez grupy alertów", ag_opt_missing: (n) => `${n} (brak)`,
    ag_url_overridden: "Wybrano grupę alertów — ten osobny URL zostanie zignorowany",
    notify_mailto_hint: "URL akceptuje też mailto:addr1,addr2 (wymaga skonfigurowanego smtp: po stronie serwera)",
    btn_backfill: "Uzupełnij", bf_hint: "Dodaj po jednym uruchomieniu na okres harmonogramu w zakresie (włącznie; istniejące okresy są pomijane, wykonanie podlega maks. aktywnym)", bf_from: "Od", bf_to: "Do", bf_go: "Uzupełnij", bf_need_dates: "Wybierz obie daty",
    bf_done: (c, s) => `Uzupełnianie zakolejkowane: utworzono ${c}, pominięto ${s}`,
    rf_all: "Wszystkie", rf_running: "Aktywne", rf_failed: "Nieudane", rf_success: "Sukces",
    t_backoff: "Wycofanie ponowień", bo_fixed: "Stałe", bo_exponential: "Wykładnicze", t_backoff_hint: "Wykładnicze: n-te ponowienie czeka delay × 2ⁿ⁻¹",
    t_backoffmax: "Limit wycofania (s)", t_backoffmax_hint: "Najdłuższy czas wykładniczego wycofania; 0 = bez limitu",
    set_sla: "SLA (miękkie)", set_sla_hint: "Od startu uruchomienia; alert jeśli nie zakończone w czasie (uruchomienie trwa dalej). 0 = wyłączone. Wymaga URL powiadomienia.", set_timeout: "Limit czasu uruchomienia (twardy)", set_timeout_hint: "Od startu uruchomienia; po przekroczeniu uruchomienie kończy się błędem i zabija działające zadania → timed_out. 0 = wyłączone.", secs: "s", set_off: "wył.",
    t_sla: "SLA zadania (s)", t_sla_hint: "Od startu uruchomienia; alert jeśli to zadanie nie zakończyło się w czasie. 0 = wyłączone.", t_timeout_hint: "Zabij pojedyncze wykonanie po tylu sekundach. 0 = brak.",
    danger_title: "Strefa niebezpieczeństwa", danger_del_hint: "Zarchiwizuj ten przepływ: brak dalszego planowania; historia zachowana.",
    nd_more: "Harmonogram i więcej", nd_less: "Ukryj",
    nav_resources: "Zmienne i połączenia", nav_audit: "Audyt", nav_api: "API", nav_ai_providers: "AI Provider", nv_ai_providers: "AI Provider", nav_aiwiki: "AI wiki", nv_aiwiki: "AI wiki",
    ai_title: "AI Provider", ai_sub: "Skonfiguruj lokalny serwer zgodny z OpenAI. Token jest szyfrowany AES-256-GCM.",
    ai_id: "ID", ai_name: "Nazwa wyświetlana", ai_url: "Base URL", ai_model: "Model", ai_token: "API Token", ai_default: "Ustaw jako domyślny",
    ai_url_ph: "http://127.0.0.1:4141/v1", ai_model_ph: "np. gpt-4o-mini", ai_name_ph: "Lokalny serwer",
    ai_need_url: "Base URL jest wymagane", ai_need_model: "Model jest wymagany", ai_need_token: "API Token jest wymagany",
    ai_save: "Zapisz provider", ai_none: "Brak skonfigurowanego AI Provider", ai_edit: "Edytuj provider", ai_add: "Nowy provider",
    ai_del_title: (n) => `Usunąć AI Provider „${n}”?`, ai_saved: "Zapisano", ai_deleted: "Usunięto",
    audit_sub: "Dziennik operacji: kto, kiedy i co zrobił z danym przepływem/uruchomieniem.", audit_empty: "Brak zarejestrowanych operacji", au_time: "Czas", au_actor: "Użytkownik", au_action: "Akcja", au_target: "Cel",
    act_trigger: "wyzwól", act_cancel: "anuluj", act_retry_run: "ponów uruchomienie", act_retry_task: "ponów zadanie", act_mark_task: "oznacz zadanie", act_mark_run: "oznacz uruchomienie", act_update_dag: "zapisz przepływ", act_create_dag: "utwórz DAG", act_delete_dag: "zarchiwizuj DAG", act_pause: "wstrzymaj", act_unpause: "wznów", act_create_token: "utwórz token", act_delete_token: "unieważnij token", act_set_alert_group: "zapisz grupę alertów", act_delete_alert_group: "usuń grupę alertów", act_set_ai_provider: "zapisz AI provider", act_delete_ai_provider: "usuń AI provider",
    api_title: "API i integracje", api_sub: "Steruj cronova z własnej platformy. Przeglądaj interaktywną dokumentację API i zarządzaj tokenami maszynowymi.",
    api_docs_h: "Dokumentacja API", api_docs_hint: "Pełna referencja OpenAPI z przykładami curl / Go / Python / Java i przełącznikiem języka na stronie.", api_open_docs: "Otwórz dokumentację API →", api_spec_link: "Specyfikacja OpenAPI",
    tok_title: "Tokeny API", tok_sub: "Dane uwierzytelniające dla maszyn. Wywołuj API z nagłówkiem Authorization: Bearer <token>. Tekst jawny widoczny tylko raz, przy tworzeniu.",
    tok_name: "Nazwa", tok_role: "Rola", tok_prefix: "Prefiks", tok_created: "Utworzono", tok_lastused: "Ostatnie użycie", tok_never: "Nigdy",
    tok_create: "Utwórz token", tok_none: "Brak tokenów", tok_name_ph: "np. ci-bot", tok_revoke: "Unieważnij", tok_need_name: "Nazwa jest wymagana",
    tok_revoke_title: (n) => `Unieważnić token „${n}”?`, tok_revoke_body: "Wywołania z tym tokenem natychmiast zawiodą. Nie można tego cofnąć.",
    tok_created_ok: "Token utworzony", tok_revoked: "Token unieważniony",
    tok_reveal_h: "Twój nowy token API", tok_reveal_warn: "Skopiuj go teraz i przechowaj bezpiecznie — nie będzie można ponownie wyświetlić tekstu jawnego.", tok_copy: "Kopiuj", tok_done: "Zapisano",
    role_admin_full: "Administrator (odczyt/zapis)", role_operator: "Operator (wyzwól/anuluj/ponów)", role_viewer_ro: "Tylko podgląd (tylko GET)",
    res_vars: "Zmienne", res_conns: "Połączenia", res_groups: "Grupy alertów",
    res_sub: "Konfiguracja współdzielona między zadaniami. Odwołuj się w poleceniach jako {{ var.KLUCZ }} / {{ conn.ID.pole }} lub {{ params.KLUCZ }} przy wyzwalaniu.",
    ag_hint: "Połącz kilka kanałów powiadomień pod jedną nazwą i odwołuj się do niej z przepływów przez notify.group; gdy zmieni się dyżur, wystarczy edytować je tutaj.",
    ag_name: "Nazwa grupy", ag_channels: "Kanały", ag_updated: "Zaktualizowano", ag_channel_n: (n) => `${n} kanał${n === 1 ? "" : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20) ? "y" : "ów"}`,
    ag_none: "Brak grup alertów", ag_add: "Nowa grupa alertów", ag_edit: "Edytuj grupę alertów",
    ag_add_channel: "+ Dodaj kanał", ag_remove_channel: "Usuń kanał", ag_fmt: "Format",
    ag_url_ph: "https://hooks.slack.com/… lub mailto:oncall@example.com",
    ag_max: (n) => `maks. ${n} kanałów`,
    ag_err_channels: "Grupa alertów wymaga 1-16 kanałów",
    ag_err_url: "URL kanału musi zaczynać się od http://, https:// lub mailto:",
    ag_mailto_hint: "Kanały mailto: wysyłane są przez serwer SMTP — najpierw skonfiguruj sekcję smtp: w pliku konfiguracyjnym",
    ag_del_title: (n) => `Usunąć grupę alertów „${n}”?`,
    ag_del_body: "Przepływy odwołujące się do niej wrócą do własnego URL powiadomień lub domyślnego — żaden alert nie zginie.",
    v_key: "Klucz", v_value: "Wartość", v_add: "Dodaj zmienną", v_none: "Brak zmiennych", v_save: "Zapisz",
    c_id: "ID połączenia", c_type: "Typ", c_host: "Host", c_port: "Port", c_login: "Login", c_password: "Hasło", c_extra: "Dodatkowe (JSON)",
    c_add: "Nowe połączenie", c_edit: "Edytuj połączenie", c_none: "Brak połączeń", c_pw_set: "ustawione", c_pw_none: "nieustawione", c_pw_keep: "pozostaw puste, aby zachować",
    c_del_title: (id) => `Usunąć połączenie „${id}"?`, v_del_title: (k) => `Usunąć zmienną „${k}"?`, del_body: "Tej operacji nie można cofnąć.",
    trig_params: "Wyzwól z parametrami", p_params: "Parametry", p_add: "Dodaj wiersz", p_key: "Klucz", p_val: "Wartość", p_trigger: "Wyzwól", p_hint: "Parametry są wstrzykiwane jako zmienne środowiskowe CRONOVA_PARAM_*; odwołuj się jako {{ params.klucz }} w poleceniach.",
    run_params: "Parametry", res_saved: "Zapisano", res_deleted: "Usunięto", err_key: "Nieprawidłowa nazwa (tylko litery, cyfry, _ . -)",
    btn_trigger: "▶ Wyzwól", btn_pause: "Wstrzymaj", btn_resume: "Wznów", btn_delete: "Usuń",
    confirm_del_dag_title: (id) => `Zarchiwizować przepływ „${id}"?`,
    confirm_del_dag_body: "Zostanie zarchiwizowany (ukryty z list); historia uruchomień zachowana, można przywrócić.",
    dag_archived: "Ten przepływ jest zarchiwizowany (usunięty).",
    confirm_word: "Potwierdź", cancel_word: "Anuluj", aria_theme: "Zmień motyw", aria_lang: "Zmień język",
    toast_run_queued: "Wyzwolono — uruchomienie zakolejkowane", toast_pool_saved: "Pool zapisany", toast_dag_deleted: "Przepływ zarchiwizowany",
    th_id: "id", th_type: "typ", th_command: "polecenie", th_deps: "zależności",
    th_logical: "data logiczna", th_state: "stan", th_trig: "wyzwalacz", th_started: "rozpoczęto", th_dur: "czas",
    th_task: "zadanie", th_try: "próba", th_logs: "logi",
    no_runs: "Brak uruchomień — wyzwól jedno.",
    k_logical: "data logiczna", k_trig: "wyzwalacz", k_dur: "czas", k_started: "rozpoczęto",
    log_word: "Log", live: "na żywo",
    pools_sub: "Globalne sloty współbieżności współdzielone przez wszystkie przepływy i uruchomienia.", p_name: "nazwa", p_slots: "sloty", p_save: "Zapisz",
    p_newname: "nazwa nowego poolu", p_create: "Utwórz pool", p_need: "wymagana nazwa i dodatnia liczba slotów",
    trig_fail: "wyzwalanie nie powiodło się", api_err: "błąd API",
    err_code_not_found: "Nie znaleziono (może zostać usunięte)",
    err_code_no_tasks: "Ten przepływ nie ma jeszcze kroków — dodaj jeden przed uruchomieniem",
    err_code_bad_mark_state: "Nieprawidłowy stan docelowy",
    err_code_queue_full: "Kolejka uruchomień pełna — spróbuj za chwilę",
    err_code_active_runs: "Ten przepływ ma aktywne uruchomienia — najpierw anuluj lub poczekaj",
    err_code_run_not_active: "To uruchomienie już się zakończyło — nie można anulować",
    err_code_nothing_to_retry: "Brak nieudanych kroków do ponowienia",
    err_code_run_still_active: "To uruchomienie wciąż trwa — ponów po zakończeniu",
    err_code_bad_group_name: "Nieprawidłowa nazwa grupy alertów (tylko litery, cyfry, _ . -; max 128 znaków)",
    err_code_dag_conflict: "Przepływ zmienił się od czasu załadowania — odśwież, aby scalić zmiany; ponowienie spowoduje kolejny konflikt",
    err_code_group_channels: "Grupa alertów wymaga 1-16 kanałów",
    err_code_group_channel_url: "URL kanału musi zaczynać się od http://, https:// lub mailto:",
    err_code_group_channel_format: "Nieprawidłowy format kanału (raw / slack / feishu / dingtalk / email)",
    dt_hint: "Trend czasu trwania: wyższy=wolniejszy, kolor=wynik; kliknij słupek, aby otworzyć uruchomienie",
    runs_more: "Załaduj więcej ↓", audit_more: "Załaduj więcej ↓", log_all: "Wszystkie zadania",
    bulk_all: "Zaznacz wszystkie (aktualny filtr)", bulk_pick: (id) => `Wybierz ${id}`,
    bulk_selected: (n) => `Wybrano ${n} przepływ${n === 1 ? "" : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20) ? "y" : "ów"}`, bulk_done: (ok, n) => `Operacja zbiorowa zakończona: ${ok}/${n} sukcesów`,
    bulk_del_title: (n) => `Zarchiwizować ${n} wybrany${n === 1 ? " przepływ" : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20) ? "e przepływy" : "ych przepływów"}?`,
    au_f_actor: "Filtruj po użytkowniku", au_f_action: "Filtruj po akcji", au_f_all: "Wszystkie",
    nx_paused: "wstrzymane", nx_due: "gotowe", nx_in: (m) => `za ${m} min`,
    b_dag_info: "Informacje o DAG",
    f_dag_id: "ID DAG", f_start: "Data startu",
    f_catchup: "Catchup", f_maxactive: "Maks. aktywnych", f_defretries: "Domyślne ponowienia",
    f_catchup_hint: "Włączone: każdy pominięty okres od start_date otrzyma uruchomienie uzupełniające (maks. jeden na tick, ograniczone maks. aktywnymi — brak burzy)",
    f_trigger_after: "Wyzwól po (sukces nadrzędnego)",
    b_addtask: "+ Dodaj zadanie", b_remove: "Usuń",
    t_id: "ID zadania", t_type: "Typ", t_command: "Polecenie", t_pool: "Pool", t_priority: "Priorytet",
    t_http: "Żądanie HTTP", http_method: "Metoda", http_url: "URL", http_headers: "Nagłówki", http_headers_hint: "Jeden na linię, Key: Value — obsługuje {{ var. }} / {{ conn. }}", http_body: "Ciało", http_status: "Oczekiwany status", http_status_hint: "Rozdzielone przecinkami, np. 200,201; puste = dowolny 2xx", err_httpurl: "Zadanie HTTP wymaga URL",
    t_python: "Kod Python", python_hint: "Python inline wykonywany przez python3 -c; zmienne CRONOVA_* dostępne w środowisku; obsługuje szablony {{ var. }}. Kod zwracający !=0 = błąd.",
    t_sql: "Zapytanie SQL", sql_conn: "Połączenie", sql_conn_hint: "ID skonfigurowanego połączenia (typ wybiera sterownik: postgres/mysql/sqlite). Zobacz Zmienne i połączenia.", err_sqlconn: "Zadanie SQL wymaga połączenia",
    t_retries: "Ponowienia (puste=domyślne)", t_retrydelay: "Opóźnienie ponowienia (s)", t_timeout: "Limit czasu (s)", t_deps: "Zależy od",
    t_nodeps: "brak innych zadań",
    t_project: "Projekt", t_optional: "(opcjonalne)", proj_none: "Brak (bez projektu)", proj_upload: "Prześlij / nowy projekt",
    proj_hint: "Gdy ustawiony, polecenie uruchamia się w czystej kopii tego projektu (np. python3 main.py). Tylko zadania shell.",
    proj_name: "Nazwa projektu", proj_name_bad: "Nazwa może zawierać tylko litery/cyfry/. _ -", proj_mode_files: "Prześlij pliki / folder", proj_mode_inline: "Napisz skrypt",
    proj_drop: "Przeciągnij pliki lub folder tutaj", proj_pick_files: "Wybierz pliki", proj_pick_folder: "Wybierz folder", proj_ziphint: "Upuszczenie .zip automatycznie rozpakuje",
    proj_filename: "Nazwa pliku", proj_content: "Treść skryptu", proj_do_upload: "Prześlij", proj_selected: (n) => `Wybrano ${n} plik${n === 1 ? "" : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20) ? "i" : "ów"}`,
    proj_uploaded: "Projekt przesłany", proj_upload_fail: "Przesyłanie nie powiodło się", proj_need_name: "Najpierw podaj nazwę projektu", proj_need_files: "Najpierw wybierz pliki lub napisz treść skryptu", proj_manage: "Zarządzaj projektami",
    err_dagid: "Wymagane prawidłowe ID DAG (litery/cyfry/_-.)", err_taskid: "Nieprawidłowe ID zadania (litery/cyfry/_-.)",
    err_dup: "Powielone ID zadania", err_emptyid: "Puste ID zadania", err_emptycmd: "Puste polecenie", err_cycle: "Wykryto cykl zależności",
    sched: "Harmonogram", sm_manual: "Ręczny", sm_every: "Interwał", sm_cron: "Wyrażenie Cron",
    sched_manual_hint: "Tylko ręczne wyzwalanie lub przez nadrzędny przepływ", sched_every_pre: "Co",
    unit_s: "s", unit_m: "min", unit_h: "h", disabled_note: "(wkrótce)",
    cp_min: "co minutę", cp_hour: "co godzinę", cp_day: "codziennie 0:00", cp_2am: "codziennie 2:00", cp_mon: "poniedziałek 0:00",
    cron_help: "pomoc", ch_title: "Format Cron", ch_format: "Format: minuta godzina dzień miesiąc dzień_tygodnia (5 pól rozdzielonych spacją)",
    ch_fields: "Pola", ch_ops: "Operatory", ch_examples: "Przykłady (kliknij, aby wypełnić)", ch_shortcuts: "Skróty",
    t_rule: "Reguła wyzwalania", tr_all_success: "wszystkie sukces", tr_all_done: "wszystkie zakończone", tr_one_success: "jeden sukces", tr_one_failed: "jeden błąd", tr_all_failed: "wszystkie błędy", tr_none_failed: "brak błędów",
    trd_all_success: "Uruchamia się tylko gdy wszystkie nadrzędne zakończą się sukcesem (domyślnie)", trd_all_done: "Uruchamia się gdy wszystkie nadrzędne zakończą, niezależnie od wyniku — dobre dla sprzątania/podsumowań", trd_one_success: "Uruchamia się gdy dowolne nadrzędne zakończy się sukcesem", trd_one_failed: "Uruchamia się gdy dowolne nadrzędne zakończy się błędem — dobre dla alertów", trd_all_failed: "Uruchamia się tylko gdy wszystkie nadrzędne zakończą się błędem", trd_none_failed: "Uruchamia się gdy żadne nadrzędne nie zakończyło się błędem (sukces lub pominięcie)",
    pool_hint: "Sloty współbieżności współdzielone przez wszystkie DAGi; zadania w tym samym poolu rywalizują o sloty",
    cb_interp: "Interpreter", cb_runas: "Uruchom jako", cb_target: "Moduł / skrypt", cb_args: "Argumenty", cb_jar: "Ścieżka JAR", cb_mainclass: "Klasa główna", cb_client: "Klient SQL", cb_query: "Zapytanie SQL",
    cmdopt_module: "moduł (-m)", cmdopt_script: "plik skryptu",
    cmd_will_run: "Wykona:", cmd_edit_raw: "edytuj surowe polecenie", cmd_use_form: "użyj formularza", cmd_cant_parse: "Nie można przetworzyć polecenia do formularza; pozostawiono edytor surowy",
    var_insert: "kliknij lub przeciągnij, aby wstawić zmienną", var_editor_aria: "edytor poleceń — wstawianie pigułek zmiennych",
    var_pill_aria: (n) => `zmienna ${n}`, var_pill_remove: (n) => `usuń zmienną ${n}`,
    var_empty: "brak", var_add_key: "własny…", var_conn_field: "pole", var_goto_settings: "ustaw",
    vd_logical_date: "logiczna data tego uruchomienia (dzień)", vd_logical_datetime: "logiczna data-czas (RFC3339)",
    vd_date_expr: "wyrażenie daty: przesunięcia ±N d/h/w/mo, kotwice .month_start/.month_end/.week_start/.week_end, format | %Y%m%d; można łączyć",
    vd_run_id: "unikalne id tego uruchomienia", vd_dag_id: "id DAG", vd_task_id: "id tego zadania", vd_try_number: "numer próby (rosnie przy ponowieniu)",
    vd_var: "zmienna współdzielona", vd_conn: "pole połączenia", vd_params: "parametr ręcznego wyzwalania",
    vg_builtin: "wbudowane", vg_var: "zmienne", vg_conn: "połączenia", vg_params: "parametry",
    graph_connect_hint: "Przeciągnij kropkę po prawej stronie węzła na inne zadanie, aby połączyć; kliknij węzeł, aby edytować zadanie; Shift+klik dwa węzły (lub włącz tryb łączenia i kliknij kolejno) również łączy/rozłącza; kliknij krawędź, aby usunąć zależność",
    ge_addtask: "+ Dodaj zadanie", ge_connect: "Tryb łączenia",
    ge_connect_tip: "Włączony: kliknij zadanie nadrzędne, potem podrzędne, aby połączyć/rozłączyć (przyjazny klawiaturze)",
    ge_new_id_title: "Nowe ID zadania", ge_edge_remove: "Usuń zależność", ge_dup_dep: "Zależność już istnieje",
    ge_edge_aria: (a, b) => `Zależność ${a} → ${b}, naciśnij Enter, aby usunąć`,
    ge_node_aria: (id) => `Zadanie ${id}`,
    diff_unsaved: (n) => `${n} niezapisana${n === 1 ? "" : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20) ? "e" : "ych"} zmiana${n === 1 ? "" : "i"}`, diff_save: "Zapisz", diff_discard: "Odrzuć",
    diff_show: "Zobacz różnice", diff_hide: "Ukryj różnice", diff_loading: "Generowanie podglądu różnic…",
    diff_invalid: "Oczekujące zmiany nie przeszły walidacji", diff_same: "Identyczne z zapisaną wersją", diff_discarded: "Odrzucono niezapisane zmiany",
    t_subdag: "Docelowy przepływ", subdag_hint: "Uruchamia inny przepływ jako uruchomienie podrzędne: to zadanie odzwierciedla końcowy stan dziecka, a anulowanie kaskaduje", subdag_none: "Wybierz przepływ…", err_subdag: "Zadanie podprzepływu wymaga docelowego przepływu",
    dod_title: "Zależność między przepływami", dod_hint: "Zadanie staje się gotowe dopiero po sukcesie uruchomienia docelowego przepływu w dopasowanym okresie",
    dod_dag: "Zależy od przepływu", dod_offset: "Przesunięcie okresu", dod_offset_hint: "- 1d / .month_start / puste = ten sam okres",
    dod_timeout: "Limit oczekiwania (s)", dod_timeout_hint: "0 = czekaj do przekroczenia limitu uruchomienia", dod_on_timeout: "Po przekroczeniu limitu",
    dod_fail: "błąd", dod_skip: "pomiń",
    parent_run: "Uruchomienie nadrzędne", child_run: "Uruchomienie podrzędne",
    nav_graph: "Graf", graph_title: "Graf przepływów", graph_sub: "Zależności wyzwalania między przepływami przez trigger_after",
    graph_none: "Brak jeszcze zależności między przepływami (żaden nie deklaruje trigger_after)", graph_view_hint: "Wskazówka: strzałki wskazują kierunek 'po wyzwoleniu'; kliknij węzeł, aby otworzyć przepływ; przerywane węzły to nieznane przepływy",
    ss_saved: "Zapisano", ss_saving: "Zapisywanie…", ss_invalid: "Napraw błędy, aby zapisać", ss_error: "Zapis nie powiódł się",
    dag_no_tasks_title: "Brak zadań", dag_no_tasks_sub: "Dodaj zadanie, aby włączyć ten przepływ", dag_disabled_hint: "Dodaj zadanie, aby umożliwić wyzwalanie",
    nd_title: "Nowy przepływ", nd_create: "Utwórz", nd_cancel: "Anuluj", nd_dagid_dup: "DAG o tym id już istnieje",
    tpl_start: "Zacznij od szablonu", tpl_tasks: "zadania",
    tpl_blank: "Pusty", tpl_blank_d: "Zacznij od zera i samodzielnie dodaj zadania",
    tpl_etl: "Codzienny ETL", tpl_etl_d: "Trzyetapowy potok: pobierz → przekształć → załaduj", tpl_etl_m: "3 kroki · każdy czeka na sukces poprzedniego",
    tpl_report: "Raport okresowy", tpl_report_d: "Pobierz dane i wyślij raport — dobre dla codziennego raportu o 8:00", tpl_report_m: "2 kroki · ustawiono codziennie 08:00",
    tpl_fanout: "Rozgałęzienie-złączenie", tpl_fanout_d: "start → dwa równoległe gałęzie → złączenie",
    coach_tpl_ready: "Szablon gotowy — kliknij „Wyzwól uruchomienie”, aby zobaczyć wykonanie, potem dostosuj zadania",
    sp_every: (n, u) => `Uruchamia się co ${n} ${u}`, sp_next: "Następne", sp_invalid: "Nieprawidłowe wyrażenie — nie można obliczyć czasów",
    tz_note: "Harmonogramy obliczane są w UTC; czasy wyświetlane w Twojej strefie lokalnej",
    btn_duplicate: "⧉ Duplikuj", dup_dag_title: "Duplikuj jako nowy przepływ (podaj nowe id)", dup_done: "Zduplikowano",
    y_copy: "Kopiuj", y_download: "Pobierz", y_close: "Zamknij", y_copied: "YAML skopiowany do schowka", y_copy_fail: "Kopiowanie nie powiodło się — zaznacz tekst ręcznie",
    nd_import_yaml: "lub wklej YAML do importu…", nd_back_form: "← wróć do formularza", nd_import: "Importuj", nd_yaml_empty: "Najpierw wklej YAML", nd_imported: "YAML zaimportowany",
    gs_title: "Pierwsze kroki", gs_create: "Utwórz pierwszy przepływ", gs_trigger: "Wyzwól uruchomienie", gs_green: "Uzyskaj zielone uruchomienie",
    adv_options: "Opcje zaawansowane", log_find_ph: "Znajdź w logu…", log_download: "Pobierz pełny log", log_matches: (n) => `${n} dopasowań`, log_capped: (n) => `pokazano ostatnie ${n} wierszy`,
    back_dag: (d) => `← Wróć do ${d}`, confirm_del_task_title: (id) => `Usunąć zadanie „${id}"?`,
    nav_workers: "Węzły robocze",
    wk_sub: "Zdalne węzły robocze podłączone do tego schedulera: stan na żywo, obciążenie oraz operacje drain/remove. Zadania kierowane są do grupy przez worker_group.",
    wk_name: "Nazwa", wk_group: "Grupa", wk_state: "Stan", wk_active: "Aktywne zadania", wk_version: "Wersja", wk_heartbeat: "Ostatni heartbeat", wk_created: "Dołączono",
    wk_online: "online", wk_offline: "offline", wk_lost: "utracony", wk_draining: "opróżniany", wk_unnamed: "(bez nazwy)",
    wk_drain: "Opróżnij", wk_undrain: "Wznów przydział",
    wk_drain_title: (n) => `Opróżnić węzeł „${n}”?`,
    wk_drain_body: "Węzeł w stanie draining nie otrzymuje nowych przydziałów; działające zadania kończą się normalnie. Można wznowić w dowolnej chwili.",
    wk_undrain_title: (n) => `Wznowić przydział dla węzła „${n}”?`,
    wk_undrain_body: "Węzeł ponownie otrzymuje przydziały zadań.",
    wk_drained_toast: "Rozpoczęto opróżnianie", wk_undrained_toast: "Przydziały wznowione",
    wk_remove: "Usuń",
    wk_remove_title: (n) => `Usunąć węzeł „${n}”?`,
    wk_remove_body: "Usunięcie jest natychmiastowe i nieodwracalne: certyfikat węzła przestaje być akceptowany, więc nie może się ponownie połączyć — ponowne dołączenie wymaga nowego tokenu.",
    wk_removed_toast: "Węzeł usunięty",
    wk_none_title: "Brak podłączonych węzłów", wk_none_sub: "Podłącz zdalny węzeł w dwóch krokach:",
    wk_join_step1: "Wygeneruj jednorazowy token dołączenia na tej stronie", wk_join_step2: "Uruchom na hoście węzła:",
    wk_token_btn: "Nowy token dołączenia", wk_token_title: "Wygeneruj jednorazowy token dołączenia",
    wk_token_ttl: "Wygasa za", wk_ttl_1h: "1 godzina", wk_ttl_24h: "24 godziny", wk_ttl_7d: "7 dni",
    wk_token_create: "Generuj",
    wk_token_reveal_h: "Twój token dołączenia", wk_token_warn: "Token widoczny tylko raz i można go użyć tylko raz — po zamknięciu nie będzie można go ponownie wyświetlić.",
    wk_join_cmd_h: "Uruchom na hoście węzła:",
    wk_expires: "Wygasa",
    err_code_workers_disabled: "Hub węzłów nie jest włączony — ustaw worker_listen w konfiguracji serwera",
    wk_disabled_hint: "Serwer nie ma włączonego huba węzłów. Skonfiguruj worker_listen w cronova.yaml (lub ustaw CRONOVA_WORKER_LISTEN), zrestartuj i spróbuj ponownie.",
    rel_now: "przed chwilą", rel_ago: (s) => `${s} temu`,
    set_policy: "Polityka wykonania",
    set_policy_hint: "Jak uruchomienia tego przepływu są dopuszczane, gdy kilka jest gotowych jednocześnie. Polityki szeregowe wymuszają maksymalnie jedno aktywne uruchomienie, niezależnie od maks. aktywnych.",
    po_parallel: "Równolegle", po_serial_wait: "Szeregowo (kolejkuj)", po_serial_discard: "Szeregowo (porzuć)", po_serial_priority: "Szeregowo (priorytet)",
    pod_parallel: "Równolegle: do maks. aktywnych uruchomień wykonuje się jednocześnie (domyślnie)",
    pod_serial_wait: "Szeregowo-kolejkuj: jedno na raz; późniejsze uruchomienia kolejkują się i wykonują w kolejności logicznej daty",
    pod_serial_discard: "Szeregowo-porzuć: jedno na raz; uruchomienia przychodzące podczas zajętości są anulowane (widocznie, nigdy po cichu)",
    pod_serial_priority: "Szeregowo-priorytet: jedno na raz; kolejka obsługiwana według priorytetu uruchomienia",
    p_priority: "Priorytet",
    p_priority_hint: "-100 do 100, domyślnie 0; wyższy wygrywa o slot (i pierwszy obsługiwany w kolejce priorytetowej)",
    run_priority_tip: "Priorytet uruchomienia: wyższy wygrywa o slot",
    mode_novice: "Prosty", mode_expert: "Ekspert",
    mode_toggle_title: "Tryb interfejsu: Prosty pokazuje tylko niezbędne informacje, Ekspert pokazuje wszystkie metryki i akcje",
    nv_workbench: "Stanowisko", nv_myflows: "Moje przepływy", nv_shared: "Wspólna konfiguracja", nv_help: "Centrum pomocy",
    nv_sys_ok: "System zdrowy", nv_newflow: "+ Nowy przepływ",
    s0_title: "Powierz powtarzające się skrypty cronova",
    s0_sub: "Uruchamia zgodnie z harmonogramem, ponawia po błędach, logi zawsze pod ręką.",
    s0_sub2: "Trzy kroki do pierwszego przepływu — około minuty.",
    s0_step1: "Wybierz punkt wyjścia", s0_step2: "Potwierdź polecenia", s0_step3: "Uruchom raz i obserwuj, jak staje się zielone",
    s0_cta: "Utwórz mój pierwszy przepływ →",
    s0_expert_link: "Używałem Airflow / Azkaban — przejdź do trybu eksperta →",
    s0_term_hint: "„Przepływ pracy” to zestaw poleceń wykonywanych po kolei — techniczna nazwa to DAG. W trybie eksperta używane jest pełne nazewnictwo.",
    wz_crumb: "Nowy przepływ", wz_back: "← Wstecz", wz_stepof: (n) => `Krok ${n} z 3`,
    wz1_title: "Wybierz scenariusz najbliższy Twojemu", wz1_sub: "Wszystko można później zmienić — to tylko punkt wyjścia.",
    wz_tpl_etl: "Codzienny potok danych", wz_tpl_etl_d: "Pobierz, przekształć, załaduj — trzy kroki po kolei", wz_tpl_etl_m: "3 kroki · każdy czeka na sukces poprzedniego",
    wz_tpl_report: "Raport okresowy", wz_tpl_report_d: "Pobierz dane i wyślij raport — dobre dla codziennego raportu o 8:00", wz_tpl_report_m: "2 kroki · ustawiono codziennie 08:00",
    wz_tpl_blank: "Od zera", wz_tpl_blank_d: "Jeden krok uruchamiający dowolne polecenie lub skrypt", wz_tpl_blank_m: "1 krok · najprostszy", wz_tpl_blank_chip: "twoje polecenie",
    wz1_next: "Dalej: potwierdź polecenia →",
    wz2_title: "Te kroki wykonują się jeden po drugim",
    wz2_sub: "Polecenie to linia, którą wpisałbyś w terminalu. Każdy krok zaczyna się dopiero po sukcesie poprzedniego; błędy są automatycznie ponawiane.",
    wz2_name_label: "Nazwij przepływ", wz2_name_hint: "Litery, cyfry lub podkreślenia — np. daily_report",
    wz2_adv: "Opcjonalnie: polecenia mogą zawierać zmienne czasu wykonania, zastępowane rzeczywistymi wartościami. Spróbuj —",
    wz2_datevar: "+ Dzisiejsza data",
    wz2_datevar_note: "dodaje na końcu polecenia kroku 1:",
    wz2_inserted: (d) => `Wstawiono ✓ zostanie zastąpione rzeczywistą datą podczas wykonania, np. --date ${d} (edytowalne w powyższym polu)`,
    wz2_next: "Dalej: kiedy ma się uruchamiać →", wz_prev: "← Wstecz",
    wz3_title: "Kiedy ma się uruchamiać?", wz3_sub: "Przybliżony wybór wystarczy — można to później zmienić.",
    wz3_daily: "Codziennie o stałej porze", wz3_daily_d: "Najczęstsze: nocne przetwarzanie danych, poranne raporty",
    wz3_interval: "Co jakiś czas", wz3_interval_d: "Dobre dla odpytywania i zadań synchronizacyjnych", wz3_every: "co", wz3_minutes: "minut",
    wz3_manual: "Tylko gdy ja to wyzwolę", wz3_manual_d: "Najpierw uruchom ręcznie — zautomatyzuj, gdy zaufasz",
    wz3_note: "Po utworzeniu przejdziemy od razu do próbnego uruchomienia, aby potwierdzić, że wszystko działa.",
    wz3_cron_hint: "W trybie eksperta to wyrażenie cron (np. 0 2 * * *) z potężniejszymi regułami.",
    wz3_create: "▶ Utwórz i uruchom raz",
    nv_sched_daily: (h) => `Będzie uruchamiany codziennie o ${h}.`, nv_sched_interval: (n) => `Będzie uruchamiany co ${n} minut.`,
    nv_sched_manual: "Uruchamia się tylko po kliknięciu „Uruchom” — nigdy automatycznie.",
    nv_gloss_daily: (h) => `codziennie o ${h}`, nv_gloss_every: (n, u) => `co ${n} ${u}`, nv_gloss_manual: "tylko ręcznie",
    nvr_running_title: (d) => `Uruchamianie ${d} …`, nvr_sub: "Kroki postępują automatycznie — nie trzeba odświeżać.",
    nvr_done_title: (d) => `Sukces w ${d}`, nvr_done_sub: "W razie błędu automatycznie ponowi i zachowa logi.",
    nvr_done_home: "Gotowe — wróć do strony głównej", nvr_detail: "Zobacz szczegóły",
    nvr_failed_title: (n, id) => `Krok ${n} ${id} nie powiódł się`,
    nvr_failed_generic: "Uruchomienie nie powiodło się",
    nvr_failed_sub: "Wcześniejsze kroki zakończyły się sukcesem; późniejsze nie zostały uruchomione. Przyczyna w ostatnich liniach logu.",
    nvr_retried: (n) => `Ponowiono automatycznie ${n} raz(y), nadal błąd.`,
    nvr_cancelled_title: "Uruchomienie anulowane", nvr_timeout_title: "Przekroczono czas uruchomienia, zatrzymano",
    nvr_cancelled_sub: "Zatrzymałeś to uruchomienie. Jeśli polecenia wyglądają dobrze, możesz uruchomić je ponownie w dowolnej chwili.",
    nvr_timeout_sub: "Uruchomienie przekroczyło limit czasu i zostało wymuszone do zatrzymania; późniejsze kroki nie zostały uruchomione.",
    nvr_rerun: "Naprawione — uruchom ponownie ▶", nvr_rerun2: "Uruchom ponownie ▶", nvr_edit_steps: "Edytuj kroki", nvr_home: "Strona główna",
    nvr_waiting: "oczekiwanie", nvr_notrun: "nie uruchomiono", nvr_running_dur: "trwa…",
    nvr_retry_n: (n) => `${n} ponowień`,
    nv_health_ok: "Wszystko dobrze",
    nv_health_line: (n) => `${n} przepływ${n === 1 ? "" : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20) ? "y" : "ów"} · brak ostatnich błędów`,
    nv_health_bad_title: (n) => `${n} przepływ${n === 1 ? "" : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20) ? "y" : "ów"} wymaga uwagi`,
    nv_health_bad_line: (id) => `${id}: ostatnie uruchomienie nie powiodło się · ponów jednym kliknięciem po naprawie`,
    nv_fix: "Napraw →", nv_metrics_link: "Pełne metryki →",
    nv_run_btn: "▶ Uruchom", nv_view_btn: "Zobacz →",
    nv_next_hints: "Następnie możesz:", nv_hint_another: "utworzyć kolejny przepływ", nv_hint_expert: "przełącz w tryb eksperta",
    nv_never_ran: "jeszcze nie uruchomiono", nv_last_run: (s) => `ostatnie uruchomienie ${s}`,
    nv_enabled: "włączone",
    nv_run_now: "▶ Uruchom teraz", nv_more: "Więcej ⋯", nv_more_title: "Wstrzymaj / duplikuj / usuń i więcej",
    nv_more_q: (id) => `Co zrobić z ${id}?`, nv_more_expert: "Edytuj w trybie eksperta",
    nv_steps_h: "Kroki", nv_steps_hint: "(w trybie eksperta nazywane „zadania / task”)",
    nv_edit: "Edytuj", nv_add_step: "+ Dodaj krok",
    nv_edit_step_title: (id) => `Edytuj krok ${id}`, nv_del_step: "Usuń ten krok",
    nv_recent_h: "Ostatnie uruchomienia", nv_view_log: "Zobacz log →",
    nv_notify_h: "Powiadomienia o błędach", nv_notify_toggle: "Powiadom mnie o błędzie",
    nv_notify_hint: "Wklej URL webhook (Slack / Feishu / DingTalk rozpoznawane automatycznie). Wiadomość wysyłana przy nieudanym uruchomieniu.",
    nv_adv_summary: "Więcej ustawień (współbieżność, ponowienia, limity czasu…)",
    nv_adv_body: (r, m) => `Domyślne wystarczą na start: ${r > 0 ? `${r} automatycznych ponowień po błędzie, ` : ""}maks. ${m} uruchomien${m > 1 ? "ia" : "ie"} jednocześnie.`,
    nv_adv_body2: "Rozwiń, gdy potrzebujesz szczegółowej kontroli, lub", nv_adv_body3: "dla wszystkich ustawień.", nv_to_expert: "przełącz w tryb eksperta",
    nv_fail_ribbon: (n, id) => `Krok ${n} ${id} nie powiódł się`, nv_fail_ribbon_generic: "Ostatnie uruchomienie nie powiodło się",
    nv_see_log: "zobacz log",
    nv_step_extract: "Pobierz dane", nv_step_transform: "Przekształć", nv_step_load: "Załaduj wyniki",
    nv_step_fetch: "Pobierz dane", nv_step_render: "Wygeneruj i wyślij raport", nv_step_1: "Pierwszy krok",
    aiwiki_title: "AI wiki — cronova", aiwiki_sub: "Zadaj pytanie o cronova. Odpowiedź powstanie na podstawie dokumentacji i DAG-ów.", aiwiki_placeholder: "Zapytaj np. jak zrobić DAG…", aiwiki_send: "Wyślij", aiwiki_close: "Zamknij",
    aiwiki_welcome: "Witaj! Jestem AI wiki cronova. Zapytaj mnie np. \"Jak zrobić DAG?\" lub \"Co to jest retry?\"",
    aiwiki_error: "Błąd połączenia z AI wiki: ", aiwiki_copied: "Skopiowano do schowka", aiwiki_triggered: "Wyzwolono DAG ", aiwiki_no_runs: "Brak runów dla DAG ",
    aiwiki_run_dag: "Uruchom ten DAG", aiwiki_dag_runs: "Historia runów", aiwiki_show_logs: "Pokaż logi", aiwiki_copy_cmd: "Kopiuj komendę CLI",
    aiwiki_open_docs: "Otwórz dokumentację", aiwiki_see_dag: "Zobacz DAG", aiwiki_browse_dags: "Przeglądaj DAG-i",
    aiwiki_sources: "Źródła: ", aiwiki_fallback: "Nie znalazłem dokładnej odpowiedzi w bazie wiedzy. Spróbuj zapytać inaczej, np. 'Jak zrobić DAG?' lub 'Co to jest retry?'.",
  },
  en: {
    workspace: "Workspace", nav_dags: "Workflows", newdag: "+ New workflow",
    f_all: "All", f_running: "Running", f_failed: "Failed", f_paused: "Paused",
    dags_sub: "Click a name for runs and structure; the left toggle pauses / resumes scheduling.",
    ov_fail_title: (id) => `${id}: latest run failed`, ov_fail_more: (n) => `${n} more failing`,
    ov_rest_ok: (n) => `the other ${n} are healthy`, ov_all_ok: "All workflows healthy", ov_last_run: (w) => `last run ${w}`,
    ov_running: "Running", ov_running_tip: "Runs currently executing", ov_rate: "Recent success", ov_go: "Investigate →",
    hlp_dag: '<b>A workflow (DAG)</b> = tasks that run in dependency order, plus a rule for when to run. <span class="eg">e.g. daily at 2:00 — extract → transform → load.</span>',
    hlp_toggle: "<b>Schedule switch.</b> Off = no more automatic runs (manual trigger still works); history is kept and it can be re-enabled any time.",
    hlp_spark: 'Each bar is one run: <b class="ok">green</b>=success, <b class="bad">red</b>=failed, <b class="run">blue</b>=running; taller = slower. Hover for details.',
    hlp_next: "Next automatic run per the schedule. “due” = waiting for a free slot.",
    hlp_rate: "Share of recent runs that succeeded (up to 14 per workflow; skips and cancellations don't count).",
    toggle_tip_on: "Enabled — click to pause scheduling", toggle_tip_off: "Paused — click to resume scheduling",
    btn_run_word: "Run", run_now_tip: "Run once now, manually — doesn't affect the schedule",
    day_today: "today", day_yesterday: "yesterday",
    h_dag: "WORKFLOW", h_spark: "LAST 14", h_pool: "POOL", h_next: "NEXT RUN",
    no_match: "No matching workflows", no_match_filter: "No workflows under this filter", no_dags_title: "No workflows yet", no_dags_sub: "Create your first workflow to start scheduling tasks.", trigger: "Trigger", manual_trigger: "manual trigger",
    back_dags: "← Workflows", run_word: "run", sub_manual: "manual trigger only", max_active: "max active",
    run_progress: "Progress",
    sec_graph: "Dependency graph", sec_structure: "Structure", sec_runs: "Run history", sec_instances: "Task instances",
    g_timeline: "Timeline", g_never_ran: "did not run", run_no_tasks: "No task instances yet for this run", run_done_ok: "Run finished — success", run_done_fail: "Run failed", run_done_timeout: "Run timed out",
    run_cancel: "Cancel run", run_retry: "Retry failed", task_retry: "Retry", run_cancelled_toast: "Run cancelled", run_retried_toast: "Re-queued",
    task_mark: "Mark state", run_mark: "Mark run", mark_skip: "Skip", mark_done_toast: "Marked",
    mark_task_title: (id) => `Mark task “${id}” as?`, mark_task_body: "Manually override the task state. A running task is stopped first; marking success/skip releases downstream tasks it was blocking.",
    mark_run_title: (id) => `Mark run “${id}” as?`, mark_run_body: "Override a finished run's recorded outcome (tasks untouched). Marking success fires downstream-workflow triggers.",
    confirm_cancel_title: (id) => `Cancel run “${id}”?`, confirm_cancel_body: "Running tasks will be killed.", th_act: "Actions",
    confirm_retry_title: (id) => `Retry “${id}”?`, confirm_retry_body: "This task and all of its downstream tasks will be reset and re-run.",
    copied: "Copied", copy_fail: "Copy failed — select the text manually", copy_hint: "Click to copy", search_ph: "Search workflows…", jump_open: "Open", jump_none: "No matching workflow",
    gz_in: "Zoom in", gz_out: "Zoom out", gz_fit: "Fit to view", gz_hint: "Drag to pan · Ctrl/⌘ + wheel to zoom",
    login_title: "Sign in to cronova", login_sub: "Enter your account credentials", login_user: "Username", login_pass: "Password", login_btn: "Sign in", login_bad: "Invalid username or password", logout: "Sign out", sess_expired: "Session expired — please sign in again", role_admin: "Admin", role_viewer: "Viewer",
    tab_runs: "Runs", tab_structure: "Structure", tab_settings: "Settings",
    dh_last: "Last run", dh_next: "Schedule", dh_rate: "Success rate", dh_never: "No runs yet", dh_norate: "—",
    set_done: "Done", set_edit: "Edit", set_none: "None", set_sched: "Schedule", set_max: "Max active runs", set_retries: "Default retries", set_deps: "Upstream workflows",
    set_deps_hint: "Triggered automatically after these workflows succeed", set_no_deps_avail: "No other workflows available",
    set_notify: "Notifications", set_notify_hint: "POST a JSON webhook when a run finishes (Slack/Feishu/Discord compatible), or reference an alert group to notify several channels at once", notify_failure: "Failure", notify_success: "Success", notify_off: "No events selected", notify_need_url: "Enter a webhook URL or pick an alert group first, then pick events", err_notify_url: "Notify URL must start with http://, https:// or mailto:",
    nf_label: "Message format", nf_hint: "raw = full JSON payload; the others wrap the summary text in that platform's incoming-webhook envelope; email is for mailto: targets", nf_feishu: "Feishu", nf_dingtalk: "DingTalk", nf_email: "Email",
    set_group: "Alert group", ag_group_none: "No alert group", ag_opt_missing: (n) => `${n} (missing)`,
    ag_url_overridden: "An alert group is selected — this standalone URL will be ignored",
    notify_mailto_hint: "The URL also accepts mailto:addr1,addr2 (requires smtp: configured on the server)",
    btn_backfill: "Backfill", bf_hint: "Enqueue one run per schedule period in the window (inclusive; existing periods are skipped, execution obeys max active runs)", bf_from: "From", bf_to: "To", bf_go: "Backfill", bf_need_dates: "Pick both dates",
    bf_done: (c, s) => `Backfill enqueued: ${c} run(s) created, ${s} skipped`,
    rf_all: "All", rf_running: "Active", rf_failed: "Failed", rf_success: "Success",
    t_backoff: "Retry backoff", bo_fixed: "Fixed", bo_exponential: "Exponential", t_backoff_hint: "Exponential: the n-th retry waits retry delay × 2ⁿ⁻¹",
    t_backoffmax: "Backoff cap (s)", t_backoffmax_hint: "Longest exponential wait; 0 = uncapped",
    set_sla: "SLA (soft)", set_sla_hint: "From run start; alert if not finished in time (run keeps going). 0 = off. Needs a notify webhook.", set_timeout: "Run timeout (hard)", set_timeout_hint: "From run start; on breach the run is force-failed and running tasks killed → timed_out. 0 = off.", secs: "sec", set_off: "off",
    t_sla: "Task SLA (sec)", t_sla_hint: "From run start; alert if this task hasn't finished in time. 0 = off.", t_timeout_hint: "Kill a single execution after this many seconds. 0 = none.",
    danger_title: "Danger zone", danger_del_hint: "Archive this workflow: no more scheduling; history is kept.",
    nd_more: "Schedule & more options", nd_less: "Hide",
    nav_resources: "Variables & Connections", nav_audit: "Audit", nav_api: "API", nav_ai_providers: "AI Provider", nv_ai_providers: "AI Provider", nav_aiwiki: "AI wiki", nv_aiwiki: "AI wiki",
    ai_title: "AI Provider", ai_sub: "Configure one OpenAI-compatible local proxy. The token is sealed with AES-256-GCM.",
    ai_id: "ID", ai_name: "Display name", ai_url: "Base URL", ai_model: "Model", ai_token: "API Token", ai_default: "Set as default",
    ai_url_ph: "http://127.0.0.1:4141/v1", ai_model_ph: "e.g. gpt-4o-mini", ai_name_ph: "Local proxy",
    ai_need_url: "Base URL is required", ai_need_model: "Model is required", ai_need_token: "API Token is required",
    ai_save: "Save provider", ai_none: "No AI provider configured yet", ai_edit: "Edit provider", ai_add: "New provider",
    ai_del_title: (n) => `Delete AI provider “${n}”?`, ai_saved: "Saved", ai_deleted: "Deleted",
    audit_sub: "Operations log: who did what to which DAG/run, and when.", audit_empty: "No operations logged yet", au_time: "Time", au_actor: "Actor", au_action: "Action", au_target: "Target",
    act_trigger: "trigger", act_cancel: "cancel", act_retry_run: "retry run", act_retry_task: "retry task", act_mark_task: "mark task", act_mark_run: "mark run", act_update_dag: "save workflow", act_create_dag: "create DAG", act_delete_dag: "delete DAG", act_pause: "pause", act_unpause: "unpause", act_create_token: "create token", act_delete_token: "revoke token", act_set_alert_group: "save alert group", act_delete_alert_group: "delete alert group", act_set_ai_provider: "save AI provider", act_delete_ai_provider: "delete AI provider",
    api_title: "API & Integration", api_sub: "Drive cronova from your own platform. Browse the interactive API reference and manage API tokens for machine access.",
    api_docs_h: "API reference", api_docs_hint: "Full OpenAPI reference with built-in curl / Go / Python / Java samples and an in-page language switcher.", api_open_docs: "Open API reference →", api_spec_link: "OpenAPI spec",
    tok_title: "API Tokens", tok_sub: "Machine credentials. Call the API with Authorization: Bearer <token>. The plaintext is shown only once, at creation.",
    tok_name: "Name", tok_role: "Role", tok_prefix: "Prefix", tok_created: "Created", tok_lastused: "Last used", tok_never: "Never used",
    tok_create: "Create token", tok_none: "No tokens yet", tok_name_ph: "e.g. ci-bot", tok_revoke: "Revoke", tok_need_name: "Name is required",
    tok_revoke_title: (n) => `Revoke token “${n}”?`, tok_revoke_body: "Calls using this token will fail immediately. This cannot be undone.",
    tok_created_ok: "Token created", tok_revoked: "Token revoked",
    tok_reveal_h: "Your new API token", tok_reveal_warn: "Copy it now and store it securely — you won't be able to see the plaintext again.", tok_copy: "Copy", tok_done: "I've saved it",
    role_admin_full: "Admin (read-write)", role_operator: "Operator (trigger/cancel/retry)", role_viewer_ro: "Viewer (GET only)",
    res_vars: "Variables", res_conns: "Connections", res_groups: "Alert groups",
    res_sub: "Config shared across tasks. Reference in commands as {{ var.KEY }} / {{ conn.ID.field }}, or {{ params.KEY }} at trigger time.",
    ag_hint: "Bundle several notify channels under one name and reference it from workflows via notify.group; when the on-call destinations change, edit them here once.",
    ag_name: "Group name", ag_channels: "Channels", ag_updated: "Updated", ag_channel_n: (n) => `${n} channel${n > 1 ? "s" : ""}`,
    ag_none: "No alert groups yet", ag_add: "New alert group", ag_edit: "Edit alert group",
    ag_add_channel: "+ Add channel", ag_remove_channel: "Remove channel", ag_fmt: "Format",
    ag_url_ph: "https://hooks.slack.com/… or mailto:oncall@example.com",
    ag_max: (n) => `up to ${n} channels`,
    ag_err_channels: "An alert group needs 1-16 channels",
    ag_err_url: "Channel URL must start with http://, https:// or mailto:",
    ag_mailto_hint: "mailto: channels are sent through the server's SMTP relay — configure the smtp: section of the config file first",
    ag_del_title: (n) => `Delete alert group “${n}”?`,
    ag_del_body: "Workflows referencing it fall back to their own notify URL or the instance default — no alert is lost.",
    v_key: "Key", v_value: "Value", v_add: "Add variable", v_none: "No variables yet", v_save: "Save",
    c_id: "Connection ID", c_type: "Type", c_host: "Host", c_port: "Port", c_login: "Login", c_password: "Password", c_extra: "Extra (JSON)",
    c_add: "New connection", c_edit: "Edit connection", c_none: "No connections yet", c_pw_set: "set", c_pw_none: "not set", c_pw_keep: "leave blank to keep",
    c_del_title: (id) => `Delete connection “${id}”?`, v_del_title: (k) => `Delete variable “${k}”?`, del_body: "This cannot be undone.",
    trig_params: "Trigger with params", p_params: "Params", p_add: "Add row", p_key: "Key", p_val: "Value", p_trigger: "Trigger", p_hint: "Params are injected as CRONOVA_PARAM_* env vars; reference as {{ params.key }} in commands.",
    run_params: "Params", res_saved: "Saved", res_deleted: "Deleted", err_key: "Invalid name (letters, digits, _ . - only)",
    btn_trigger: "▶ Trigger run", btn_pause: "Pause", btn_resume: "Resume", btn_delete: "Delete",
    confirm_del_dag_title: (id) => `Archive workflow “${id}”?`,
    confirm_del_dag_body: "It will be archived (hidden from lists); run history is kept and it can be restored.",
    dag_archived: "This workflow is archived (deleted).",
    confirm_word: "Confirm", cancel_word: "Cancel", aria_theme: "Toggle theme", aria_lang: "Switch language",
    toast_run_queued: "Triggered — run queued", toast_pool_saved: "Pool saved", toast_dag_deleted: "Workflow archived",
    th_id: "id", th_type: "type", th_command: "command", th_deps: "deps",
    th_logical: "logical date", th_state: "state", th_trig: "trigger", th_started: "started", th_dur: "duration",
    th_task: "task", th_try: "try", th_logs: "logs",
    no_runs: "No runs yet — trigger one.",
    k_logical: "logical date", k_trig: "trigger", k_dur: "duration", k_started: "started",
    log_word: "Log", live: "live",
    pools_sub: "Global concurrency slots, shared across all workflows and runs.", p_name: "name", p_slots: "slots", p_save: "Save",
    p_newname: "new pool name", p_create: "Create pool", p_need: "name + positive slots required",
    trig_fail: "trigger failed", api_err: "API error",
    err_code_not_found: "Not found (it may have been deleted)",
    err_code_no_tasks: "This workflow has no steps yet — add one before running it",
    err_code_bad_mark_state: "That state is not a valid mark target",
    err_code_queue_full: "The run queue is full — try again shortly",
    err_code_active_runs: "This workflow still has active runs — cancel or wait for them first",
    err_code_run_not_active: "This run has already finished — nothing to cancel",
    err_code_nothing_to_retry: "This run has no failed steps to retry",
    err_code_run_still_active: "This run is still active — retry it after it finishes",
    err_code_bad_group_name: "Invalid alert group name (letters, digits, _ . - only; max 128 chars)",
    err_code_dag_conflict: "This workflow changed since you loaded it — reload to merge your edits; retrying will conflict again",
    err_code_group_channels: "An alert group needs 1-16 channels",
    err_code_group_channel_url: "Channel URL must start with http://, https:// or mailto:",
    err_code_group_channel_format: "Invalid channel format (raw / slack / feishu / dingtalk / email)",
    dt_hint: "Duration trend: taller = slower, color = outcome; click a bar to open that run",
    runs_more: "Load more ↓", audit_more: "Load more ↓", log_all: "All tasks",
    bulk_all: "Select all (current filter)", bulk_pick: (id) => `Select ${id}`,
    bulk_selected: (n) => `${n} workflow${n > 1 ? "s" : ""} selected`, bulk_done: (ok, n) => `Bulk action done: ${ok}/${n} succeeded`,
    bulk_del_title: (n) => `Archive the ${n} selected workflow${n > 1 ? "s" : ""}?`,
    au_f_actor: "Filter by actor", au_f_action: "Filter by action", au_f_all: "All",
    nx_paused: "paused", nx_due: "due", nx_in: (m) => `in ${m}m`,
    b_dag_info: "DAG info",
    f_dag_id: "DAG ID", f_start: "Start date",
    f_catchup: "Catchup", f_maxactive: "Max active", f_defretries: "Default retries",
    f_catchup_hint: "When on, every schedule period missed since start_date gets a backfilled run (at most one per tick, bounded by max active runs — no thundering herd)",
    f_trigger_after: "Trigger after (upstream success)",
    b_addtask: "+ Add task", b_remove: "Remove",
    t_id: "Task ID", t_type: "Type", t_command: "Command", t_pool: "Pool", t_priority: "Priority",
    t_http: "HTTP request", http_method: "Method", http_url: "URL", http_headers: "Headers", http_headers_hint: "One per line, Key: Value — supports {{ var. }} / {{ conn. }}", http_body: "Body", http_status: "Expected status", http_status_hint: "Comma-separated, e.g. 200,201; empty = any 2xx", err_httpurl: "HTTP task requires a URL",
    t_python: "Python code", python_hint: "Inline Python run with python3 -c; CRONOVA_* vars are in the environment; supports {{ var. }} templates. Non-zero exit = failure.",
    t_sql: "SQL query", sql_conn: "Connection", sql_conn_hint: "A configured connection id (its type picks the driver: postgres/mysql/sqlite). See Variables & Connections.", err_sqlconn: "SQL task requires a connection",
    t_retries: "Retries (empty=default)", t_retrydelay: "Retry delay (s)", t_timeout: "Timeout (s)", t_deps: "Depends on",
    t_nodeps: "no other tasks",
    t_project: "Project", t_optional: "(optional)", proj_none: "None (no project)", proj_upload: "Upload / new project",
    proj_hint: "When set, the command runs inside a clean copy of this project (e.g. python3 main.py). Shell tasks only.",
    proj_name: "Project name", proj_name_bad: "Name may contain only letters/digits/. _ -", proj_mode_files: "Upload files / folder", proj_mode_inline: "Write a script",
    proj_drop: "Drag files or a folder here", proj_pick_files: "Choose files", proj_pick_folder: "Choose folder", proj_ziphint: "Drop a .zip to auto-extract",
    proj_filename: "Filename", proj_content: "Script content", proj_do_upload: "Upload", proj_selected: (n) => `${n} file(s) selected`,
    proj_uploaded: "Project uploaded", proj_upload_fail: "Upload failed", proj_need_name: "Enter a project name first", proj_need_files: "Choose files or write script content first", proj_manage: "Manage projects",
    err_dagid: "Valid DAG ID required (letters/digits/_-.)", err_taskid: "Invalid task ID (letters/digits/_-.)",
    err_dup: "Duplicate task ID", err_emptyid: "Empty task ID", err_emptycmd: "Empty command", err_cycle: "Dependency cycle detected",
    sched: "Schedule", sm_manual: "Manual", sm_every: "Interval", sm_cron: "Cron expression",
    sched_manual_hint: "Manual trigger or triggered by an upstream workflow only", sched_every_pre: "Every",
    unit_s: "sec", unit_m: "min", unit_h: "hr", disabled_note: "(coming soon)",
    cp_min: "every minute", cp_hour: "hourly", cp_day: "daily 0:00", cp_2am: "daily 2:00", cp_mon: "Mon 0:00",
    cron_help: "help", ch_title: "Cron format", ch_format: "Format: min hour day month weekday (5 space-separated fields)",
    ch_fields: "Fields", ch_ops: "Operators", ch_examples: "Examples (click to fill)", ch_shortcuts: "Shortcuts",
    t_rule: "Trigger rule", tr_all_success: "all success", tr_all_done: "all done", tr_one_success: "one success", tr_one_failed: "one failed", tr_all_failed: "all failed", tr_none_failed: "none failed",
    trd_all_success: "Runs only if all upstreams succeeded (default)", trd_all_done: "Runs once all upstreams finish, success or not — good for cleanup/summary", trd_one_success: "Runs as soon as any upstream succeeds", trd_one_failed: "Runs as soon as any upstream fails — good for alerts", trd_all_failed: "Runs only if all upstreams failed", trd_none_failed: "Runs if no upstream failed (succeeded or skipped)",
    pool_hint: "Concurrency slots shared across all DAGs; tasks in the same pool compete for its slots",
    cb_interp: "Interpreter", cb_runas: "Run as", cb_target: "Module / script", cb_args: "Arguments", cb_jar: "Jar path", cb_mainclass: "Main class", cb_client: "SQL client", cb_query: "SQL query",
    cmdopt_module: "module (-m)", cmdopt_script: "script file",
    cmd_will_run: "Will run:", cmd_edit_raw: "edit raw command", cmd_use_form: "use form", cmd_cant_parse: "This command can't be parsed into the form; keeping the raw editor",
    var_insert: "click or drag to insert a variable", var_editor_aria: "command editor — insert variable pills",
    var_pill_aria: (n) => `variable ${n}`, var_pill_remove: (n) => `remove variable ${n}`,
    var_empty: "none", var_add_key: "custom…", var_conn_field: "field", var_goto_settings: "set up",
    vd_logical_date: "this run's logical date (day)", vd_logical_datetime: "logical date-time (RFC3339)",
    vd_date_expr: "date expression: ±N d/h/w/mo offsets, .month_start/.month_end/.week_start/.week_end anchors, | %Y%m%d custom format; composable",
    vd_run_id: "this run's unique id", vd_dag_id: "the DAG id", vd_task_id: "this task's id", vd_try_number: "attempt number (increments on retry)",
    vd_var: "shared variable", vd_conn: "connection field", vd_params: "manual-trigger param",
    vg_builtin: "built-in", vg_var: "variables", vg_conn: "connections", vg_params: "params",
    graph_connect_hint: "Drag the dot on a node's right edge onto another task to connect; click a node to edit the task; Shift+click two nodes (or toggle connect mode and click them in turn) also connects/disconnects; click an edge to remove the dependency",
    ge_addtask: "+ Add task", ge_connect: "Connect mode",
    ge_connect_tip: "When on: click the upstream task, then the downstream task to connect/disconnect (keyboard friendly)",
    ge_new_id_title: "New task ID", ge_edge_remove: "Remove dependency", ge_dup_dep: "Dependency already exists",
    ge_edge_aria: (a, b) => `Dependency ${a} → ${b}, press Enter to remove`,
    ge_node_aria: (id) => `Task ${id}`,
    diff_unsaved: (n) => `${n} unsaved change${n > 1 ? "s" : ""}`, diff_save: "Save", diff_discard: "Discard",
    diff_show: "View diff", diff_hide: "Hide diff", diff_loading: "Building diff preview…",
    diff_invalid: "Pending changes fail validation", diff_same: "Identical to the saved version", diff_discarded: "Unsaved changes discarded",
    t_subdag: "Target workflow", subdag_hint: "Runs another workflow as a child run: this task mirrors the child run's terminal state, and cancel cascades into it", subdag_none: "Pick a workflow…", err_subdag: "A sub-workflow task needs a target workflow",
    dod_title: "Cross-workflow dependency", dod_hint: "The task becomes ready only after the target workflow's matching period run succeeds",
    dod_dag: "Depends on workflow", dod_offset: "Period offset", dod_offset_hint: "- 1d / .month_start / blank = same period",
    dod_timeout: "Wait timeout (sec)", dod_timeout_hint: "0 = wait until the run times out", dod_on_timeout: "On timeout",
    dod_fail: "fail", dod_skip: "skip",
    parent_run: "Parent run", child_run: "Child run",
    nav_graph: "Graph", graph_title: "Workflow Graph", graph_sub: "Trigger dependencies between workflows via trigger_after",
    graph_none: "No cross-workflow dependencies yet (none declares trigger_after)", graph_view_hint: "Tip: arrows point in the trigger-after direction; click a node to open that workflow; dashed nodes are unknown workflows",
    ss_saved: "Saved", ss_saving: "Saving…", ss_invalid: "Fix errors to save", ss_error: "Save failed",
    dag_no_tasks_title: "No tasks yet", dag_no_tasks_sub: "Add a task to enable this workflow", dag_disabled_hint: "Add a task to enable triggering",
    nd_title: "New workflow", nd_create: "Create", nd_cancel: "Cancel", nd_dagid_dup: "A DAG with this id already exists",
    tpl_start: "Start from a template", tpl_tasks: "tasks",
    tpl_blank: "Blank", tpl_blank_d: "Start empty and add tasks yourself",
    tpl_etl: "Daily ETL", tpl_etl_d: "Three-step extract → transform → load pipeline",
    tpl_report: "Scheduled report", tpl_report_d: "Fetch → render, preset to run daily at 08:00",
    tpl_fanout: "Fan-out / fan-in", tpl_fanout_d: "start → two parallel branches → join",
    coach_tpl_ready: "Template ready — hit “Trigger run” to watch it execute, then tweak the tasks",
    sp_every: (n, u) => `Runs every ${n} ${u}`, sp_next: "Next", sp_invalid: "Invalid expression — cannot compute fire times",
    tz_note: "Schedules evaluate in UTC; times shown in your local timezone",
    btn_duplicate: "⧉ Duplicate", dup_dag_title: "Duplicate as a new workflow (enter a new id)", dup_done: "Duplicated",
    y_copy: "Copy", y_download: "Download", y_close: "Close", y_copied: "YAML copied to clipboard", y_copy_fail: "Copy failed — select the text manually",
    nd_import_yaml: "or paste YAML to import…", nd_back_form: "← back to the form", nd_import: "Import", nd_yaml_empty: "Paste some YAML first", nd_imported: "YAML imported",
    gs_title: "Getting started", gs_create: "Create your first workflow", gs_trigger: "Trigger a run", gs_green: "Get a green run",
    adv_options: "Advanced options", log_find_ph: "Find in log…", log_download: "Download full log", log_matches: (n) => `${n} matching lines`, log_capped: (n) => `showing last ${n} lines`,
    back_dag: (d) => `← Back to ${d}`, confirm_del_task_title: (id) => `Delete task “${id}”?`,
    // ---- workers fleet ----
    nav_workers: "Workers",
    wk_sub: "Remote workers dialed into this scheduler: live state, load, and drain/remove operations. Tasks route to a group via worker_group.",
    wk_name: "Name", wk_group: "Group", wk_state: "State", wk_active: "Active tasks", wk_version: "Version", wk_heartbeat: "Last heartbeat", wk_created: "Joined",
    wk_online: "online", wk_offline: "offline", wk_lost: "lost", wk_draining: "draining", wk_unnamed: "(unnamed)",
    wk_drain: "Drain", wk_undrain: "Undrain",
    wk_drain_title: (n) => `Drain worker “${n}”?`,
    wk_drain_body: "A draining worker gets no new assignments; its running tasks finish normally. You can undrain it any time.",
    wk_undrain_title: (n) => `Undrain worker “${n}”?`,
    wk_undrain_body: "The worker resumes receiving task assignments.",
    wk_drained_toast: "Draining started", wk_undrained_toast: "Assignments resumed",
    wk_remove: "Remove",
    wk_remove_title: (n) => `Remove worker “${n}”?`,
    wk_remove_body: "Removal is immediate and cannot be undone: the worker's certificate stops being accepted, so it cannot reconnect — rejoining requires a fresh join token.",
    wk_removed_toast: "Worker removed",
    wk_none_title: "No workers have joined yet", wk_none_sub: "Attach a remote worker in two steps:",
    wk_join_step1: "Mint a one-time join token on this page", wk_join_step2: "Run on the worker host:",
    wk_token_btn: "New join token", wk_token_title: "Mint a one-time join token",
    wk_token_ttl: "Expires in", wk_ttl_1h: "1 hour", wk_ttl_24h: "24 hours", wk_ttl_7d: "7 days",
    wk_token_create: "Mint token",
    wk_token_reveal_h: "Your join token",
    wk_token_warn: "This token is shown only once and can be used only once — you won't see it again after closing.",
    wk_join_cmd_h: "Run on the worker host:",
    wk_expires: "Expires",
    err_code_workers_disabled: "Worker hub is not enabled — set worker_listen in the server config",
    wk_disabled_hint: "The server has no worker hub enabled. Configure worker_listen in cronova.yaml (or set CRONOVA_WORKER_LISTEN), restart, and try again.",
    rel_now: "just now", rel_ago: (s) => `${s} ago`,
    // ---- execution policy + trigger priority ----
    set_policy: "Execution policy",
    set_policy_hint: "How runs of this workflow are admitted when several are ready at once. Serial policies force at most one active run, whatever Max active runs says.",
    po_parallel: "Parallel", po_serial_wait: "Serial (wait)", po_serial_discard: "Serial (discard)", po_serial_priority: "Serial (priority)",
    pod_parallel: "Parallel: up to Max active runs execute concurrently (default)",
    pod_serial_wait: "Serial wait: one at a time; later runs queue and execute in logical-date order",
    pod_serial_discard: "Serial discard: one at a time; runs arriving while busy are cancelled (visibly, never silently)",
    pod_serial_priority: "Serial priority: one at a time; the queue drains highest run priority first",
    p_priority: "Priority",
    p_priority_hint: "-100 to 100, default 0; higher wins the competition for dispatch slots (and drains first from a serial_priority queue)",
    run_priority_tip: "Run priority: higher wins dispatch-slot competition",
    // ---- novice mode ----
    mode_novice: "Simple", mode_expert: "Expert",
    mode_toggle_title: "Interface mode: Simple keeps only the essentials; Expert shows every metric and action",
    nv_workbench: "Workbench", nv_myflows: "My workflows", nv_shared: "Shared config", nv_help: "Help center",
    nv_sys_ok: "System healthy", nv_newflow: "+ New workflow",
    s0_title: "Hand your repetitive scripts to cronova",
    s0_sub: "Runs on schedule, retries on failure, logs always at hand.",
    s0_sub2: "Three steps to your first workflow — about a minute.",
    s0_step1: "Pick a starting point", s0_step2: "Confirm the commands", s0_step3: "Run once, watch it go green",
    s0_cta: "Create my first workflow →",
    s0_expert_link: "I've used Airflow / Azkaban — take me to expert mode →",
    s0_term_hint: "A “workflow” is a set of commands run in order — the technical term is DAG. Expert mode uses the full terminology.",
    wz_crumb: "New workflow", wz_back: "← Back", wz_stepof: (n) => `Step ${n} of 3`,
    wz1_title: "Pick the scenario closest to yours", wz1_sub: "Everything can be changed later — this is just a starting point.",
    wz_tpl_etl: "Daily data pipeline", wz_tpl_etl_d: "Fetch, transform, then load — three steps in order", wz_tpl_etl_m: "3 steps · each waits for the previous to succeed",
    wz_tpl_report: "Scheduled report", wz_tpl_report_d: "Fetch data and send a report — great for a daily 8am digest", wz_tpl_report_m: "2 steps · preset daily 08:00",
    wz_tpl_blank: "From scratch", wz_tpl_blank_d: "A single step running any command or script of yours", wz_tpl_blank_m: "1 step · simplest", wz_tpl_blank_chip: "your command",
    wz1_next: "Next: confirm commands →",
    wz2_title: "These steps run one after another",
    wz2_sub: "A command is the line you'd type in a terminal. Each step starts only after the previous succeeds; failures retry automatically.",
    wz2_name_label: "Name your workflow", wz2_name_hint: "Letters, digits or underscores — e.g. daily_report",
    wz2_adv: "Optional: commands can embed runtime variables, replaced with real values at run time. Try it —",
    wz2_datevar: "+ Today's date",
    wz2_datevar_note: "appends to the end of step 1's command:",
    wz2_inserted: (d) => `Inserted ✓ replaced with the actual date at run time, e.g. --date ${d} (editable in the input above)`,
    wz2_next: "Next: when should it run →", wz_prev: "← Previous",
    wz3_title: "When should it run?", wz3_sub: "A rough choice is fine — change it any time later.",
    wz3_daily: "Every day at a fixed time", wz3_daily_d: "Most common: crunch data at night, send reports in the morning",
    wz3_interval: "At a regular interval", wz3_interval_d: "Good for polling and sync jobs", wz3_every: "every", wz3_minutes: "minutes",
    wz3_manual: "Only when I trigger it", wz3_manual_d: "Run it by hand first — automate once you trust it",
    wz3_note: "After creating, we'll take you straight to a trial run to confirm everything works.",
    wz3_cron_hint: "In expert mode this is a cron expression (e.g. 0 2 * * *) with more powerful rules.",
    wz3_create: "▶ Create & run once",
    nv_sched_daily: (h) => `It will run automatically every day at ${h}.`, nv_sched_interval: (n) => `It will run automatically every ${n} minutes.`,
    nv_sched_manual: "It only runs when you click “Run” — never automatically.",
    nv_gloss_daily: (h) => `daily at ${h}`, nv_gloss_every: (n, u) => `every ${n} ${u}`, nv_gloss_manual: "manual only",
    nvr_running_title: (d) => `Running ${d} …`, nvr_sub: "Steps advance automatically — no need to refresh.",
    nvr_done_title: (d) => `Run succeeded in ${d}`, nvr_done_sub: "On failure it retries automatically and keeps the logs here.",
    nvr_done_home: "Done — back home", nvr_detail: "View details",
    nvr_failed_title: (n, id) => `Step ${n} ${id} failed`,
    nvr_failed_generic: "The run failed",
    nvr_failed_sub: "Earlier steps succeeded; later ones didn't run. See the last lines of the log for the cause.",
    nvr_retried: (n) => `Retried ${n} time(s) automatically, still failing.`,
    nvr_cancelled_title: "Run cancelled", nvr_timeout_title: "Run timed out and was stopped",
    nvr_cancelled_sub: "You stopped this run. If the commands look right, run it again any time.",
    nvr_timeout_sub: "The run exceeded its time limit and was force-stopped; later steps did not run.",
    nvr_rerun: "Fixed — run again ▶", nvr_rerun2: "Run again ▶", nvr_edit_steps: "Edit steps", nvr_home: "Home",
    nvr_waiting: "waiting", nvr_notrun: "did not run", nvr_running_dur: "running…",
    nvr_retry_n: (n) => `${n} retr${n > 1 ? "ies" : "y"}`,
    nv_health_ok: "All good",
    nv_health_line: (n) => `${n} workflow${n > 1 ? "s" : ""} · no recent failures`,
    nv_health_bad_title: (n) => `${n} workflow${n > 1 ? "s" : ""} need${n > 1 ? "" : "s"} attention`,
    nv_health_bad_line: (id) => `${id}'s latest run failed · rerun with one click once fixed`,
    nv_fix: "Fix it →", nv_metrics_link: "Full metrics →",
    nv_run_btn: "▶ Run", nv_view_btn: "View →",
    nv_next_hints: "Next you could:", nv_hint_another: "create another workflow", nv_hint_expert: "switch to expert mode for everything else",
    nv_never_ran: "hasn't run yet", nv_last_run: (s) => `last run ${s}`,
    nv_enabled: "enabled",
    nv_run_now: "▶ Run now", nv_more: "More ⋯", nv_more_title: "Pause / duplicate / delete and more",
    nv_more_q: (id) => `What to do with ${id}?`, nv_more_expert: "Edit in expert mode",
    nv_steps_h: "Steps", nv_steps_hint: "(called “tasks” in expert mode)",
    nv_edit: "Edit", nv_add_step: "+ Add step",
    nv_edit_step_title: (id) => `Edit step ${id}`, nv_del_step: "Delete this step",
    nv_recent_h: "Recent runs", nv_view_log: "View log →",
    nv_notify_h: "Failure alerts", nv_notify_toggle: "Notify me on failure",
    nv_notify_hint: "Paste an incoming-webhook URL (Slack / Feishu / DingTalk auto-detected). A message is sent when a run fails.",
    nv_adv_summary: "More settings (concurrency, retries, timeouts…)",
    nv_adv_body: (r, m) => `The defaults are enough to start: ${r > 0 ? `${r} automatic retr${r > 1 ? "ies" : "y"} on failure, ` : ""}at most ${m} run${m > 1 ? "s" : ""} at a time.`,
    nv_adv_body2: "Expand when you need fine control, or", nv_adv_body3: "for every setting.", nv_to_expert: "switch to expert mode",
    nv_fail_ribbon: (n, id) => `Step ${n} ${id} failed`, nv_fail_ribbon_generic: "The latest run failed",
    nv_see_log: "view log",
    nv_step_extract: "Extract data", nv_step_transform: "Transform", nv_step_load: "Load results",
    nv_step_fetch: "Fetch data", nv_step_render: "Render & send report", nv_step_1: "First step",
    aiwiki_title: "AI wiki — cronova", aiwiki_sub: "Ask a question about cronova. The answer is built from the documentation and DAGs.", aiwiki_placeholder: "Ask something like how to create a DAG…", aiwiki_send: "Send", aiwiki_close: "Close",
    aiwiki_welcome: "Hi! I'm the cronova AI wiki. Ask me e.g. \"How do I create a DAG?\" or \"What is retry?\"",
    aiwiki_error: "AI wiki connection error: ", aiwiki_copied: "Copied to clipboard", aiwiki_triggered: "Triggered DAG ", aiwiki_no_runs: "No runs for DAG ",
    aiwiki_run_dag: "Run this DAG", aiwiki_dag_runs: "Run history", aiwiki_show_logs: "Show logs", aiwiki_copy_cmd: "Copy CLI command",
    aiwiki_open_docs: "Open documentation", aiwiki_see_dag: "View DAG", aiwiki_browse_dags: "Browse DAGs",
    aiwiki_sources: "Sources: ", aiwiki_fallback: "I couldn't find an exact answer in the knowledge base. Try rephrasing, e.g. 'How do I create a DAG?' or 'What is retry?'.",
  },
};
const STATE = {
  pl: { success: "sukces", failed: "błąd", running: "trwa", queued: "w kolejce", scheduled: "zaplanowane", up_for_retry: "ponawianie", upstream_failed: "błąd nadrzędnego", skipped: "pominięte", cancelled: "anulowane", timed_out: "przekroczono czas", "": "brak uruchomień", none: "brak uruchomień" },
  en: { success: "success", failed: "failed", running: "running", queued: "queued", scheduled: "scheduled", up_for_retry: "retrying", upstream_failed: "upstream failed", skipped: "skipped", cancelled: "cancelled", timed_out: "timed out", "": "no runs", none: "no runs" },
};
const TYPEL = {
  pl: { schedule: "zaplanowane", manual: "ręczne", dependency: "zależność", event: "zdarzenie", backfill: "uzupełnienie", subdag: "podprzepływ" },
  en: { schedule: "scheduled", manual: "manual", dependency: "dependency", event: "event", backfill: "backfill", subdag: "sub-workflow" },
};
function t(k, ...a) { const v = (DICT[lang][k] ?? DICT.pl[k] ?? DICT.en[k] ?? k); return typeof v === "function" ? v(...a) : v; }
const stateLabel = (s) => STATE[lang][s] ?? STATE.pl[s] ?? STATE.en[s] ?? s;
const typeLabel = (s) => TYPEL[lang][s] ?? TYPEL.pl[s] ?? TYPEL.en[s] ?? s;
// next_schedule label from backend ("paused"/"due"/"in Nm"/"—"/date) -> localized
function nextLabel(s) {
  if (s === "paused") return t("nx_paused");
  if (s === "due") return t("nx_due");
  const m = /^in (\d+)m$/.exec(s);
  if (m) return t("nx_in", m[1]);
  return s; // "—" or absolute date
}
function descLabel(d) { return d === "manual trigger" ? t("manual_trigger") : d; }
const ID_RE = /^[A-Za-z0-9][A-Za-z0-9_.-]*$/;

// ---- helpers ----
async function api(path, opts) {
  const r = await fetch(path, opts);
  if (!r.ok) {
    // Prefer the machine code (localizable) over the raw English error string;
    // unknown codes fall back to the server's message so nothing is lost.
    let m = r.statusText, code = "";
    try { const b = await r.json(); m = b.error || m; code = b.code || ""; } catch (_) {}
    if (code) { const loc = t("err_code_" + code); if (loc !== "err_code_" + code) m = loc; }
    const err = new Error(m); err.status = r.status; err.code = code;
    // session expired mid-use → bounce to login (not during the auth calls themselves)
    if (r.status === 401 && authUser && !path.startsWith("/api/login") && !path.startsWith("/api/me")) {
      authUser = null; showLogin(true);
    }
    throw err;
  }
  const ct = r.headers.get("content-type") || "";
  return ct.includes("json") ? r.json() : r.text();
}
const esc = (s) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
// copySpan: a click-to-copy value (handled by the delegated [data-copy] listener
// in boot.js). Keyboard-activatable via the global Enter/Space delegation. An
// aria-label conveys the copy action to screen readers (role=button otherwise
// announces only the value); title (defaults to the copy hint) can carry the full
// value for a truncated cell.
function copySpan(text, cls, titleText) {
  const title = titleText || t("copy_hint");
  return `<span class="copyable ${cls || ""}" data-copy="${esc(text)}" role="button" tabindex="0" title="${esc(title)}" aria-label="${t("copy_hint")}: ${esc(text)}">${esc(text)}</span>`;
}
// copyText: clipboard write that works in INSECURE contexts too. navigator.clipboard
// is undefined on any non-localhost http:// origin (the console's real topology),
// so fall back to a hidden textarea + execCommand. Resolves to whether it copied.
function copyText(text) {
  if (navigator.clipboard && window.isSecureContext) {
    return navigator.clipboard.writeText(text).then(() => true, () => legacyCopy(text));
  }
  return Promise.resolve(legacyCopy(text));
}
function legacyCopy(text) {
  try {
    const ta = document.createElement("textarea");
    ta.value = text; ta.setAttribute("readonly", "");
    ta.style.cssText = "position:fixed;left:-9999px;opacity:0";
    document.body.appendChild(ta); ta.select();
    const ok = document.execCommand("copy");
    document.body.removeChild(ta);
    return ok;
  } catch (_) { return false; }
}
const fmt = (x) => (x ? new Date(x).toLocaleString() : "—");
// friendly short time for banner copy: today 08:12 / yesterday 08:12 / Aug 7 08:12
function fmtDay(x) {
  if (!x) return "—";
  const d = new Date(x);
  if (isNaN(d)) return "—";
  const hm = d.toLocaleTimeString(lang === "pl" ? "pl-PL" : "en-US", { hour: "2-digit", minute: "2-digit", hour12: false });
  const key = (a) => a.getFullYear() * 10000 + a.getMonth() * 100 + a.getDate();
  const now = new Date(), yd = new Date(now); yd.setDate(yd.getDate() - 1);
  if (key(d) === key(now)) return `${t("day_today")} ${hm}`;
  if (key(d) === key(yd)) return `${t("day_yesterday")} ${hm}`;
  const md = lang === "pl" ? `${d.getDate()}.${d.getMonth() + 1}` : d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
  return `${md} ${hm}`;
}
// compact "how long ago" label (e.g. worker heartbeats): just now / 5s ago / 3m ago / 2h ago;
// anything older than a day falls back to the friendly day format above.
function relTime(x) {
  if (!x) return "—";
  const d = new Date(x);
  if (isNaN(d)) return "—";
  const s = Math.max(0, Math.round((Date.now() - d) / 1000));
  if (s < 5) return t("rel_now");
  if (s < 60) return t("rel_ago", s + "s");
  if (s < 3600) return t("rel_ago", Math.floor(s / 60) + "m");
  if (s < 86400) return t("rel_ago", Math.floor(s / 3600) + "h");
  return fmtDay(x);
}

// ---- toast + in-app confirm (themed + bilingual; replaces native alert/confirm) ----
// kind: ok | fail | warn | info. Success/info auto-dismiss; errors persist until clicked.
function toast(msg, kind = "ok") {
  const host = $("toast-root"); if (!host) return;
  const el = document.createElement("div");
  el.className = "toast t-" + kind;
  el.setAttribute("role", kind === "fail" ? "alert" : "status");
  el.textContent = msg;
  const dismiss = () => { el.classList.remove("in"); setTimeout(() => el.remove(), 220); };
  el.onclick = dismiss;
  host.appendChild(el);
  requestAnimationFrame(() => el.classList.add("in"));
  if (kind !== "fail") setTimeout(dismiss, 3200);
}
// Promise<bool> confirm dialog reusing the .overlay/.modal markup. Escape=cancel,
// Enter=confirm, click-outside=cancel. opts: {danger, okLabel}.
function confirmDialog(title, body, opts = {}) {
  return new Promise((resolve) => {
    const root = $("modal-root");
    root.innerHTML = `<div class="overlay" id="cfm-ovl"><div class="modal confirm" role="dialog" aria-modal="true" aria-label="${esc(title)}">
      <h2>${esc(title)}</h2>
      <div class="body">${body ? `<p class="cfm-body">${esc(body)}</p>` : ""}</div>
      <div class="foot"><button id="cfm-cancel">${esc(t("cancel_word"))}</button><button class="${opts.danger ? "danger" : "primary"}" id="cfm-ok">${esc(opts.okLabel || t("confirm_word"))}</button></div>
    </div></div>`;
    const close = (v) => { document.removeEventListener("keydown", onKey); root.innerHTML = ""; resolve(v); };
    const onKey = (e) => { if (e.key === "Escape") close(false); else if (e.key === "Enter") close(true); };
    document.addEventListener("keydown", onKey);
    $("cfm-cancel").onclick = () => close(false);
    $("cfm-ok").onclick = () => close(true);
    $("cfm-ovl").onclick = (e) => { if (e.target.id === "cfm-ovl") close(false); };
    $("cfm-ok").focus();
  });
}
// Promise<value|null> single-choice picker reusing the .overlay/.modal markup.
// options: [{value, label, danger}]. Escape / click-outside / Cancel resolve null.
function pickDialog(title, body, options) {
  return new Promise((resolve) => {
    const root = $("modal-root");
    const btns = options.map((o, i) => `<button class="${o.danger ? "danger" : (i === 0 ? "primary" : "")}" data-pick="${esc(String(o.value))}">${esc(o.label)}</button>`).join("");
    root.innerHTML = `<div class="overlay" id="pick-ovl"><div class="modal confirm" role="dialog" aria-modal="true" aria-label="${esc(title)}">
      <h2>${esc(title)}</h2>
      <div class="body">${body ? `<p class="cfm-body">${esc(body)}</p>` : ""}</div>
      <div class="foot pick-foot"><button id="pick-cancel">${esc(t("cancel_word"))}</button>${btns}</div>
    </div></div>`;
    const close = (v) => { document.removeEventListener("keydown", onKey); root.innerHTML = ""; resolve(v); };
    const onKey = (e) => { if (e.key === "Escape") close(null); };
    document.addEventListener("keydown", onKey);
    $("pick-cancel").onclick = () => close(null);
    root.querySelectorAll("[data-pick]").forEach((b) => b.onclick = () => close(b.dataset.pick));
    $("pick-ovl").onclick = (e) => { if (e.target.id === "pick-ovl") close(null); };
    const first = root.querySelector("[data-pick]"); if (first) first.focus();
  });
}
function dur(a, b) { if (!a) return "—"; const ms = (b ? new Date(b) : new Date()) - new Date(a); if (ms < 0) return "—"; const s = Math.round(ms / 1000); return s < 60 ? `${s}s` : `${Math.floor(s / 60)}m${s % 60}s`; }
function badge(s, sm) { const k = s || "none"; return `<span class="badge${sm ? " sm" : ""} s-${k}"><span class="d"></span>${stateLabel(s)}</span>`; }
// ?-bubble with a rich HTML tip from the dict. pos: "" above-left, "r" above-right, "b" below
function hlp(key, pos) {
  const html = t(key);
  return `<span class="hlp${pos ? " hlp-" + pos : ""}" tabindex="0" aria-label="${esc(html.replace(/<[^>]+>/g, ""))}">?<span class="tip" aria-hidden="true">${html}</span></span>`;
}
let logESAll = []; // extra streams opened by the all-tasks combined log view
function closeLog() {
  if (logES) { logES.close(); logES = null; }
  logESAll.forEach((es) => { try { es.close(); } catch (_) {} });
  logESAll = [];
}
// human label for a seconds threshold (SLA / timeout); 0 => "off".
function secsLabel(sec) {
  sec = +sec || 0;
  if (sec <= 0) return t("set_off");
  if (sec < 60) return sec + "s";
  if (sec < 3600) return Math.floor(sec / 60) + "m" + (sec % 60 ? (sec % 60) + "s" : "");
  const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60);
  return h + "h" + (m ? m + "m" : "");
}
// compact duration label from a millisecond count (dashboard sparkline + activity)
function fmtMs(ms) { if (!ms || ms < 0) return "—"; if (ms < 1000) return `${ms}ms`; const s = Math.round(ms / 1000); return s < 60 ? `${s}s` : `${Math.floor(s / 60)}m${s % 60}s`; }
function sparkline(points, scaleMs) {
  // points: [{state, ms}] oldest→newest (tolerates legacy [string]). Height now
  // HONESTLY encodes real run duration for finished runs (taller = longer). We
  // scale against a DASHBOARD-WIDE max (scaleMs, passed by renderDags) so "taller
  // = slower" reads consistently across DAGs; no-run/skipped stay short stubs and
  // running/queued (no duration yet) get a neutral mid bar — never a fabricated one.
  const arr = (points || []).slice(-14).map((p) => (typeof p === "string" ? { state: p, ms: 0 } : p));
  while (arr.length < 14) arr.unshift({ state: "noruns", ms: 0 });
  const maxMs = Math.max(1, scaleMs || 0, ...arr.map((p) => p.ms || 0));
  const LO = 6, HI = 22;
  return `<div class="spark">${arr.map((p) => {
    const k = p.state || "noruns", stub = k === "noruns" || k === "skipped";
    let h;
    if (stub) h = LO;
    else if (p.ms > 0) h = Math.round(LO + (p.ms / maxMs) * (HI - LO)); // duration-scaled
    else h = 15; // running/queued: active, duration unknown — neutral, not fabricated
    const label = k === "noruns" ? stateLabel("none") : (p.ms > 0 ? `${stateLabel(k)} · ${fmtMs(p.ms)}` : stateLabel(k));
    return `<i class="${esc(k)}" style="height:${h}px" title="${esc(label)}"></i>`;
  }).join("")}</div>`;
}

// ---- graph ----
// [fill, stroke] for a task/run state, single-sourced from the theme vars (via
// color-mix) so the graph re-themes live. Injected into the node rect's inline
// `style` — only literal token strings here, never user data.
function colorForState(s) {
  const tint = (v, p) => [`color-mix(in srgb, var(${v}) ${p}%, transparent)`, `var(${v})`];
  const m = {
    success: tint("--ok", 15), failed: tint("--fail", 16), running: tint("--run", 16),
    up_for_retry: tint("--warn", 16), queued: tint("--warn", 12), scheduled: tint("--warn", 10),
    upstream_failed: tint("--upstream", 12), skipped: tint("--skip", 18), cancelled: tint("--skip", 22),
    timed_out: tint("--fail", 20),
  };
  return m[s] || ["var(--panel-2)", "var(--line-2)"]; // neutral: follows theme
}
function renderGraph(tasks, stateByTask, opts) {
  opts = opts || {};
  if (!tasks || !tasks.length) return `<div class="empty">—</div>`;
  // Decorations for cross-DAG waits: a task carrying depends_on_dag gets a small
  // dashed "external DAG" stub node feeding it (read-only, layout-only — the
  // stub id never leaks into the real model). Stubs are shared per target dag.
  const EXT = "__ext__";
  const list = tasks.map((t2) => ({ ...t2, deps: (t2.deps || []).slice() }));
  const stubs = {};
  const extEdges = new Set(); // "from|to" pairs drawn dashed (external waits)
  list.forEach((t2) => {
    const ext = t2.dod || (t2.depends_on_dag && t2.depends_on_dag.dag) || "";
    if (!ext) return;
    const sid = EXT + ext;
    stubs[sid] ||= { id: sid, deps: [], extDag: ext };
    t2.deps.push(sid);
    extEdges.add(sid + "|" + t2.id);
  });
  const all = [...Object.values(stubs), ...list];
  const byId = {}; all.forEach((t2) => byId[t2.id] = t2);
  const level = {};
  const lvl = (id, seen) => { if (level[id] != null) return level[id]; if (seen.has(id)) return 0; seen.add(id); const deps = (byId[id]?.deps || []).filter((d) => byId[d]); return level[id] = deps.length ? 1 + Math.max(...deps.map((d) => lvl(d, seen))) : 0; };
  all.forEach((t2) => lvl(t2.id, new Set()));
  const cols = {}; all.forEach((t2) => (cols[level[t2.id]] ||= []).push(t2.id));
  const NW = 150, NH = 36, CG = 200, RG = 52, PAD = 16, pos = {};
  Object.keys(cols).forEach((L) => cols[L].forEach((id, i) => pos[id] = { x: PAD + L * CG, y: PAD + i * RG }));
  const maxL = Math.max(...Object.keys(cols).map(Number)), maxR = Math.max(...Object.values(cols).map((c) => c.length));
  const W = PAD * 2 + maxL * CG + NW, H = PAD * 2 + (maxR - 1) * RG + NH;
  let edges = "", nodes = "";
  all.forEach((t2) => (t2.deps || []).forEach((d) => {
    if (!pos[d]) return;
    const x1 = pos[d].x + NW, y1 = pos[d].y + NH / 2, x2 = pos[t2.id].x, y2 = pos[t2.id].y + NH / 2, mx = (x1 + x2) / 2;
    const dPath = `M${x1} ${y1} C ${mx} ${y1}, ${mx} ${y2}, ${x2} ${y2}`;
    const isExt = extEdges.has(d + "|" + t2.id);
    // editable graphs get a per-edge group with a wide invisible hit path so a
    // dependency can be selected/removed by pointer or keyboard.
    const hit = opts.editable && !isExt
      ? `<path class="edge-hit" d="${dPath}" tabindex="0" role="button" aria-label="${esc(t("ge_edge_aria", d, t2.id))}"/>` : "";
    edges += `<g class="edge-g${isExt ? " ext" : ""}" data-efrom="${esc(d)}" data-eto="${esc(t2.id)}"><path class="graph-edge" d="${dPath}"/>${hit}</g>`;
  }));
  all.forEach((t2) => {
    const p = pos[t2.id];
    if (t2.extDag) { // external-DAG stub: dashed, decorative, never interactive
      nodes += `<g class="graph-node ext" aria-hidden="true"><rect x="${p.x}" y="${p.y + 4}" width="${NW}" height="${NH - 8}" rx="8" style="fill:var(--panel-2);stroke:var(--line-2)" stroke-width="1.2" stroke-dasharray="4 4"/><text x="${p.x + NW / 2}" y="${p.y + NH / 2 + 4}" text-anchor="middle">⌁ ${esc(t2.extDag.length > 16 ? t2.extDag.slice(0, 15) + "…" : t2.extDag)}</text></g>`;
      return;
    }
    let [f, st] = colorForState(stateByTask ? stateByTask[t2.id] : null);
    let sw = 1.2;
    if (opts.pending === t2.id) { st = "var(--accent)"; sw = 2.6; }
    const dash = opts.dashed && opts.dashed.has(t2.id) ? ` stroke-dasharray="5 4"` : "";
    // tag: expose data-node for live patching without making the node clickable
    const clickable = opts.editable || opts.clickable;
    const attrs = clickable
      ? ` data-node="${esc(t2.id)}" style="cursor:pointer"${opts.editable ? ` tabindex="0" role="button" aria-label="${esc(t("ge_node_aria", t2.id))}"` : ""}`
      : (opts.tag ? ` data-node="${esc(t2.id)}"` : "");
    const cls = "graph-node" + (opts.tag && stateByTask && stateByTask[t2.id] === "running" ? " g-running" : "") + (t2.subdag ? " subdag" : "");
    // subdag task: double border + ⧉ marker + the target dag id as a subtitle
    const inner = t2.subdag ? `<rect class="g-inner" x="${p.x + 3}" y="${p.y + 3}" width="${NW - 6}" height="${NH - 6}" rx="5.5" style="stroke:${st}" stroke-width="1"/>` : "";
    const label = t2.subdag
      ? `<text x="${p.x + NW / 2}" y="${p.y + NH / 2 - 1}" text-anchor="middle">⧉ ${esc(t2.id)}</text><text class="g-sub" x="${p.x + NW / 2}" y="${p.y + NH / 2 + 11}" text-anchor="middle">${esc(t2.subdag.length > 20 ? t2.subdag.slice(0, 19) + "…" : t2.subdag)}</text>`
      : `<text x="${p.x + NW / 2}" y="${p.y + NH / 2 + 4}" text-anchor="middle">${esc(t2.id)}</text>`;
    // editable nodes carry a connector handle on the right edge: edge-drag starts
    // ONLY here, so a plain node-body drag still pans (and touch pinch survives)
    const handle = opts.editable
      ? `<circle class="gh-hit" cx="${p.x + NW}" cy="${p.y + NH / 2}" r="11" data-ghandle="${esc(t2.id)}"/><circle class="gh" cx="${p.x + NW}" cy="${p.y + NH / 2}" r="5" data-ghandle="${esc(t2.id)}" aria-hidden="true"/>` : "";
    // fill/stroke via inline style (SVG presentation attributes don't resolve color-mix reliably)
    nodes += `<g class="${cls}"${attrs}><rect x="${p.x}" y="${p.y}" width="${NW}" height="${NH}" rx="8" style="fill:${f};stroke:${st}" stroke-width="${sw}"${dash}/>${inner}${label}${handle}</g>`;
  });
  // compact height for small graphs; capped so a big graph pans/zooms instead of
  // dominating the page. attachPanZoom() wires drag-pan + ctrl/⌘-wheel zoom.
  const wrapH = Math.min(H + 24, 460);
  const zoom = `<div class="graph-zoom" aria-hidden="false">
    <button class="gz" data-z="in" aria-label="${t("gz_in")}" title="${t("gz_in")}">+</button>
    <button class="gz" data-z="fit" aria-label="${t("gz_fit")}" title="${esc(t("gz_hint"))}">⤢</button>
    <button class="gz" data-z="out" aria-label="${t("gz_out")}" title="${t("gz_out")}">−</button></div>`;
  return `<div class="graph-wrap" style="height:${wrapH}px" title="${esc(t("gz_hint"))}"><svg class="graph-svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${edges}${nodes}</svg>${zoom}</div>`;
}
// Pan/zoom controller for a .graph-wrap. Operates via a CSS transform on the
// inner <svg> (vectors stay crisp; node click handlers + live rect-fill patching
// are untouched). Idempotent per element. Never traps plain page scroll — wheel
// zoom requires Ctrl/⌘. A drag past a small threshold suppresses the trailing
// click, so panning over a node doesn't activate it.
//   store: optional {s,tx,ty} holder that survives the element (e.g. the editable
//   graph is destroyed + rebuilt on every dependency edit). When it carries a
//   saved view we reseed from it; otherwise a graph larger than its box auto-fits
//   on attach (the old overflow:auto used to expose oversized graphs via scroll).
function attachPanZoom(wrap, store) {
  if (!wrap || wrap.dataset.pz) return; wrap.dataset.pz = "1";
  const svg = wrap.querySelector("svg"); if (!svg) return;
  const cw = svg.viewBox.baseVal.width, ch = svg.viewBox.baseVal.height; // content bounds
  const MIN = 0.25, MAX = 4;
  const seeded = store && store.s != null;
  let s = seeded ? store.s : 1, tx = seeded ? store.tx : 0, ty = seeded ? store.ty : 0;
  // viewport size, robust to a transient 0 (pre-layout / offscreen reflow)
  const vpW = () => wrap.clientWidth || wrap.getBoundingClientRect().width || 0;
  const vpH = () => wrap.clientHeight || wrap.getBoundingClientRect().height || 0;
  const apply = () => {
    svg.style.transform = `translate(${tx.toFixed(2)}px,${ty.toFixed(2)}px) scale(${s.toFixed(4)})`;
    if (store) { store.s = s; store.tx = tx; store.ty = ty; } // persist across re-render
  };
  const clamp = () => { // keep a margin of content on-screen so it can't be lost
    const vw = vpW(), vh = vpH(), m = 44;
    if (vw < 10 || vh < 10) return; // not laid out — don't clamp against garbage
    tx = Math.min(vw - m, Math.max(m - cw * s, tx));
    ty = Math.min(vh - m, Math.max(m - ch * s, ty));
  };
  const zoomAt = (px, py, ns) => {
    ns = Math.min(MAX, Math.max(MIN, ns));
    tx = px - (px - tx) * (ns / s); ty = py - (py - ty) * (ns / s);
    s = ns; clamp(); apply();
  };
  const fit = () => {
    const vw = vpW(), vh = vpH(), pad = 18;
    if (vw < 10 || vh < 10) return; // keep current view rather than compute a garbage scale
    s = Math.min(1, Math.max(MIN, Math.min((vw - pad * 2) / cw, (vh - pad * 2) / ch))); // never enlarge past natural
    tx = (vw - cw * s) / 2; ty = (vh - ch * s) / 2; apply();
  };
  wrap.addEventListener("wheel", (e) => {
    if (!(e.ctrlKey || e.metaKey)) return; // plain wheel → page scrolls normally
    e.preventDefault();
    const r = wrap.getBoundingClientRect();
    zoomAt(e.clientX - r.left, e.clientY - r.top, s * (e.deltaY < 0 ? 1.12 : 1 / 1.12));
  }, { passive: false });
  let drag = false, moved = false, sx = 0, sy = 0, otx = 0, oty = 0;
  // touch: track active pointers so two fingers pinch-zoom (mobile has no
  // Ctrl+wheel); a second finger cancels the pan and hands over to the pinch.
  const touches = new Map(); // pointerId -> {x, y}
  let pinchDist = 0;
  wrap.addEventListener("pointerdown", (e) => {
    if (e.pointerType !== "touch" && e.button !== 0) return;
    wrap._sup = 0; // any fresh press clears a stale suppress-latch (e.g. drag released off-element)
    if (e.target.closest(".graph-zoom")) return; // let the zoom buttons handle themselves
    if (e.pointerType === "touch") {
      touches.set(e.pointerId, { x: e.clientX, y: e.clientY });
      if (touches.size === 2) {
        drag = false; wrap.classList.remove("panning");
        const [a, b] = [...touches.values()];
        pinchDist = Math.hypot(a.x - b.x, a.y - b.y);
        wrap._sup = 1; // the pinch must not synthesize a node click
        return;
      }
    }
    drag = true; moved = false; sx = e.clientX; sy = e.clientY; otx = tx; oty = ty;
    try { wrap.setPointerCapture(e.pointerId); } catch (_) {}
  });
  wrap.addEventListener("pointermove", (e) => {
    if (e.pointerType === "touch" && touches.has(e.pointerId)) {
      touches.set(e.pointerId, { x: e.clientX, y: e.clientY });
      if (touches.size === 2) {
        const [a, b] = [...touches.values()];
        const d = Math.hypot(a.x - b.x, a.y - b.y);
        if (pinchDist > 0 && d > 0) {
          const r = wrap.getBoundingClientRect();
          zoomAt((a.x + b.x) / 2 - r.left, (a.y + b.y) / 2 - r.top, s * (d / pinchDist));
        }
        pinchDist = d;
        return;
      }
    }
    if (!drag) return;
    const dx = e.clientX - sx, dy = e.clientY - sy;
    if (!moved && Math.hypot(dx, dy) < 4) return; // below threshold: still a click
    moved = true; wrap.classList.add("panning");
    tx = otx + dx; ty = oty + dy; clamp(); apply();
  });
  const end = (e) => {
    if (e && e.pointerType === "touch") { touches.delete(e.pointerId); if (touches.size < 2) pinchDist = 0; }
    if (!drag) return;
    drag = false; wrap.classList.remove("panning"); if (moved) wrap._sup = 1;
  };
  wrap.addEventListener("pointerup", end);
  wrap.addEventListener("pointercancel", end);
  // capture-phase: swallow the click synthesized after a pan so node handlers don't
  // fire — but never suppress the zoom controls (a keyboard/mouse zoom-button click
  // has no preceding wrap pointerdown, so it must not be eaten by a stale latch).
  wrap.addEventListener("click", (e) => {
    if (e.target.closest(".graph-zoom")) return;
    if (wrap._sup) { e.stopPropagation(); e.preventDefault(); wrap._sup = 0; }
  }, true);
  wrap.querySelector(".graph-zoom").addEventListener("click", (e) => {
    const b = e.target.closest("[data-z]"); if (!b) return;
    e.stopPropagation();
    const vw = vpW(), vh = vpH();
    if (b.dataset.z === "in") zoomAt(vw / 2, vh / 2, s * 1.25);
    else if (b.dataset.z === "out") zoomAt(vw / 2, vh / 2, s / 1.25);
    else fit();
  });
  apply(); // identity (or reseeded view) — avoids a first-frame flash
  if (!seeded) {
    // frame an oversized graph once layout is known (clientWidth is 0 synchronously)
    requestAnimationFrame(() => {
      const vw = vpW(), vh = vpH();
      if (vw >= 10 && vh >= 10 && (cw > vw + 1 || ch > vh + 1)) fit();
    });
  }
}

// ---- sidebar/topbar ----
// ---- hash routing: every drill-down is linkable and refresh-safe ----
let suppressHash = false;
function resetMainScroll() {
  if (main) main.scrollTop = 0;
}
function finishRouteRender() {
  resetMainScroll();
  requestAnimationFrame(resetMainScroll);
}
// replace=true rewrites the current entry (no new history entry, no hashchange) —
// use it for in-page normalization (e.g. tab canonicalization) so Back isn't trapped.
function setHash(h, replace) {
  if (location.hash === h) return;
  resetMainScroll();
  if (replace) { history.replaceState(null, "", h); return; }
  suppressHash = true; location.hash = h;
}
function applyRoute() {
  if (typeof closeConnMenu === "function") closeConnMenu(); // dismiss any open popover on navigation
  const seg = location.hash.replace(/^#\/?/, "").split("/").map(decodeURIComponent).filter(Boolean);
  if (!seg.length || seg[0] === "dags") return loadDags();
  if (seg[0] === "new") return showWizard();
  if (seg[0] === "pools") return showPools();
  if (seg[0] === "resources") return showResources();
  if (seg[0] === "graph") return showGraph();
  if (seg[0] === "audit") return showAudit();
  if (seg[0] === "workers") return showWorkers();
  if (seg[0] === "api") return showApi();
  if (seg[0] === "ai-providers") return showAIProviders();
  if (seg[0] === "run" && seg[1]) return showRun(seg[1]);
  if (seg[0] === "dag" && seg[1] && seg[2] === "task" && seg[3]) {
    return showDag(seg[1]).then(() => { if (D && D.dag.dag_id === seg[1] && D.tasks.some((x) => x.id === seg[3])) showTask(seg[1], seg[3]); });
  }
  if (seg[0] === "dag" && seg[1]) return showDag(seg[1], seg[2]); // seg[2]: runs|structure|settings (optional)
  return loadDags();
}
window.addEventListener("hashchange", () => {
  if (suppressHash) { suppressHash = false; return; }
  resetMainScroll();
  Promise.resolve(applyRoute()).then(finishRouteRender).catch(() => {});
});

// ---- global quick-jump: the topbar search doubles as a "jump to any DAG" box
// (an autocomplete dropdown), available on every page — not just a dashboard filter.
let jumpDags = [], jumpSel = -1;
async function ensureJumpDags() {
  if (overviewCache && overviewCache.dags) { jumpDags = overviewCache.dags.map((d) => d.dag_id); return; }
  if (jumpDags.length) return;
  try { jumpDags = (await api("/api/dags")).map((d) => d.dag_id); } catch (_) {}
}
function hlMatch(id, q) {
  const i = id.toLowerCase().indexOf(q);
  if (i < 0) return esc(id);
  return esc(id.slice(0, i)) + `<b>${esc(id.slice(i, i + q.length))}</b>` + esc(id.slice(i + q.length));
}
function updateJump(raw) {
  const menu = $("jump-menu"); if (!menu) return;
  const q = raw.trim().toLowerCase();
  if (overviewCache && overviewCache.dags) jumpDags = overviewCache.dags.map((d) => d.dag_id); // freshest
  const setExpanded = (v) => $("search").setAttribute("aria-expanded", v);
  const clearAD = () => $("search").removeAttribute("aria-activedescendant");
  if (!q) { menu.hidden = true; menu.innerHTML = ""; jumpSel = -1; setExpanded("false"); clearAD(); return; }
  const matches = jumpDags.filter((id) => id.toLowerCase().includes(q)).slice(0, 8);
  menu.hidden = false; setExpanded("true");
  if (!matches.length) { menu.innerHTML = `<div class="jump-empty">${t("jump_none")}</div>`; jumpSel = -1; clearAD(); return; }
  jumpSel = 0;
  menu.innerHTML = matches.map((id, i) => `<div class="jump-item ${i === 0 ? "sel" : ""}" id="jump-opt-${i}" data-jump="${esc(id)}" role="option" aria-selected="${i === 0}"><span class="mono">${hlMatch(id, q)}</span><span class="jump-open">${t("jump_open")} →</span></div>`).join("");
  menu.querySelectorAll("[data-jump]").forEach((it) => it.onmousedown = (e) => { e.preventDefault(); jumpTo(it.dataset.jump); }); // mousedown beats blur
  $("search").setAttribute("aria-activedescendant", "jump-opt-0"); // SR announces the active option
}
function jumpMove(delta) {
  const menu = $("jump-menu"); if (!menu || menu.hidden) return;
  const items = [...menu.querySelectorAll(".jump-item")]; if (!items.length) return;
  jumpSel = (jumpSel + delta + items.length) % items.length;
  items.forEach((it, i) => { it.classList.toggle("sel", i === jumpSel); it.setAttribute("aria-selected", i === jumpSel); });
  $("search").setAttribute("aria-activedescendant", "jump-opt-" + jumpSel);
  items[jumpSel].scrollIntoView({ block: "nearest" });
}
function jumpEnter() {
  const menu = $("jump-menu"); if (!menu || menu.hidden) return false;
  const sel = menu.querySelectorAll(".jump-item")[jumpSel];
  if (sel) { jumpTo(sel.dataset.jump); return true; }
  return false;
}
function jumpTo(dagID) { closeJump(); const s = $("search"); s.value = ""; query = ""; if (view === "dags") renderDags(); showDag(dagID); }
function closeJump() { const m = $("jump-menu"); if (m) { m.hidden = true; m.innerHTML = ""; jumpSel = -1; } $("search").setAttribute("aria-expanded", "false"); $("search").removeAttribute("aria-activedescendant"); }

let serverTZ = "";
async function loadInfo() { try { const i = await api("/api/info"); serverTZ = i.tz || ""; $("f-exec").textContent = i.executor || "—"; $("f-tick").textContent = "tick " + (i.tick || "—"); $("tick").textContent = "tick " + (i.tick || "—"); const v = $("side-version"); if (v) v.textContent = "scheduler " + (i.version || "dev"); const z = $("tzlab"); if (z) { z.textContent = serverTZ; z.title = t("tz_note"); } } catch (_) {} }
// ---- auth: login gate + user chip ----
// Resolve who we are. /api/me is 200 (authed, or auth-disabled → implicit admin)
// or 401 (login required). Returns whether the app may start.
async function initAuth() {
  try { authUser = await api("/api/me"); }
  catch (e) {
    if (e.status === 401) { showLogin(false); return false; }
    authUser = { role: "admin", auth: false }; // transient error: don't hard-block
    return true;
  }
  document.body.dataset.role = authUser.role || "admin";
  renderUserChip();
  return true;
}
function renderUserChip() {
  const el = $("user-chip"); if (!el) return;
  if (!authUser || authUser.auth === false || !authUser.username) { el.hidden = true; el.innerHTML = ""; return; }
  const roleLbl = authUser.role === "viewer" ? t("role_viewer") : t("role_admin");
  el.hidden = false;
  el.innerHTML = `<div class="uc-id"><span class="uc-name">${esc(authUser.username)}</span><span class="uc-role">${roleLbl}</span></div><button class="uc-logout" id="uc-logout">${t("logout")}</button>`;
  $("uc-logout").onclick = doLogout;
  const nd = $("newdag"); if (nd) nd.style.display = authUser.role === "admin" ? "" : "none"; // hide write CTA for viewers
}
async function doLogout() {
  try { await api("/api/logout", { method: "POST" }); } catch (_) {}
  authUser = null; showLogin(false);
}
function showLogin(expired) {
  const root = $("login-root"); if (!root) return;
  root.innerHTML = `
    <div class="login-overlay">
      <form class="login-card" id="login-form" novalidate>
        <div class="login-logo"><span class="logo" style="width:22px;height:22px;font-size:13px">c</span> cronova</div>
        <div class="login-h">${t("login_title")}</div>
        <div class="login-sub">${expired ? t("sess_expired") : t("login_sub")}</div>
        <label class="login-lbl">${t("login_user")}<input id="login-user" autocomplete="username"></label>
        <label class="login-lbl">${t("login_pass")}<input id="login-pass" type="password" autocomplete="current-password"></label>
        <div class="login-err" id="login-err" hidden></div>
        <button class="primary login-submit" type="submit">${t("login_btn")}</button>
      </form>
    </div>`;
  const form = $("login-form"), errEl = $("login-err"), btn = form.querySelector("button");
  form.onsubmit = async (e) => {
    e.preventDefault(); btn.disabled = true; errEl.hidden = true;
    try {
      await api("/api/login", { method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username: $("login-user").value, password: $("login-pass").value }) });
      root.innerHTML = "";
      if (await initAuth()) startApp();
    } catch (err) {
      errEl.textContent = err.status === 401 ? t("login_bad") : (err.message || t("api_err"));
      errEl.hidden = false; btn.disabled = false;
      $("login-pass").value = ""; $("login-pass").focus();
    }
  };
  $("login-user").focus();
}
// startApp runs the normal boot once we know the user is authorized.
async function startApp() {
  await resolveMode();
  loadInfo();
  Promise.resolve(applyRoute()).catch((e) => { main.innerHTML = `<div class="empty err">${t("api_err")}: ${esc(e.message)}</div>`; });
}

// ---- novice/expert mode ----
// Effective mode: saved preference, else inferred once per boot from the store
// (empty instance => novice onboarding; existing DAGs => expert, so upgrading
// never flips a working console). Inference isn't persisted — only a toggle click is.
async function resolveMode() {
  const saved = localStorage.getItem("cnv_mode");
  if (saved === "novice" || saved === "expert") uiMode = saved;
  else {
    try { overviewCache = await api("/api/overview"); uiMode = overviewCache.stats.total_dags > 0 ? "expert" : "novice"; }
    catch (_) { uiMode = "expert"; }
  }
  document.documentElement.dataset.mode = uiMode;
  syncModeChrome();
}
function setMode(m) {
  if (uiMode === m) return;
  uiMode = m; localStorage.setItem("cnv_mode", m);
  document.documentElement.dataset.mode = m;
  syncModeChrome();
  Promise.resolve(applyRoute()).then(finishRouteRender).catch(() => {});
}
// sync the topbar chrome that depends on mode: segmented toggle + primary CTA label
function syncModeChrome() {
  if (!uiMode) return;
  const tg = $("mode-toggle");
  if (tg) {
    tg.hidden = false;
    tg.title = t("mode_toggle_title");
    const nv = $("mode-nov"), ex = $("mode-exp");
    if (nv) { nv.classList.toggle("on", nvMode()); nv.setAttribute("aria-pressed", nvMode()); }
    if (ex) { ex.classList.toggle("on", !nvMode()); ex.setAttribute("aria-pressed", !nvMode()); }
  }
  const nd = $("newdag"); if (nd) nd.textContent = t(nvMode() ? "nv_newflow" : "newdag");
}
// display label for a step/task id — glosses the ids our own templates create,
// falls back to the raw id for anything user-authored (honest, no guessing)
const TASK_LABELS = { extract: "nv_step_extract", transform: "nv_step_transform", load: "nv_step_load", fetch: "nv_step_fetch", render: "nv_step_render", step_1: "nv_step_1" };
function nvTaskLabel(id) { return TASK_LABELS[id] ? t(TASK_LABELS[id]) : id; }
// stable topological order (Kahn) so novice screens can number steps 1..N;
// cycles can't occur in saved DAGs (validated), but tolerate them anyway.
function topoOrder(tasks) {
  const byId = {}; (tasks || []).forEach((tk) => byId[tk.id] = tk);
  const out = [], done = new Set();
  let progress = true;
  while (out.length < (tasks || []).length && progress) {
    progress = false;
    for (const tk of tasks) {
      if (done.has(tk.id)) continue;
      if ((tk.deps || []).every((d) => done.has(d) || !byId[d])) { out.push(tk); done.add(tk.id); progress = true; }
    }
  }
  for (const tk of tasks || []) if (!done.has(tk.id)) out.push(tk); // cycle fallback
  return out;
}
// plain-language schedule gloss for novice screens. Only shapes we're sure of
// ("M H * * *" daily cron, @every, empty); anything else shows the raw expression.
function nvSchedGloss(schedule) {
  const s = (schedule || "").trim();
  if (!s) return t("nv_gloss_manual");
  let m = /^(\d{1,2})\s+(\d{1,2})\s+\*\s+\*\s+\*$/.exec(s);
  if (m) return t("nv_gloss_daily", `${String(m[2]).padStart(2, "0")}:${String(m[1]).padStart(2, "0")}`);
  m = /^@every\s+(\d+)(s|m|h)$/.exec(s);
  if (m) return t("nv_gloss_every", m[1], t("unit_" + m[2]));
  return s;
}

// navKey highlights a sidebar item; crumb (optional) overrides the topbar breadcrumb text.
let lastNavLabel = null;
function setNav(navKey, crumb) {
  document.body.dataset.screen = view; // lets CSS hide chrome per screen (e.g. mode toggle on the wizard)
  document.querySelectorAll(".nav-item[data-nav]").forEach((n) => n.classList.toggle("active", n.dataset.nav === navKey));
  // novice mode names the same pages in its own words (shared config / my workflows)
  const label = crumb != null ? crumb : (navKey === "pools" ? "Pools" : navKey === "graph" ? t("graph_title") : navKey === "resources" ? t(nvMode() ? "nv_shared" : "nav_resources") : navKey === "ai-providers" ? t(nvMode() ? "nv_ai_providers" : "nav_ai_providers") : navKey === "aiwiki" ? t(nvMode() ? "nv_aiwiki" : "nav_aiwiki") : navKey === "audit" ? t("nav_audit") : navKey === "workers" ? t("nav_workers") : navKey === "api" ? t("nav_api") : t(nvMode() ? "nv_myflows" : "nav_dags"));
  $("crumb").textContent = label;
  // the topbar search only filters the dashboard list — hide it elsewhere.
  // search stays visible everywhere now (global jump-to-DAG), not just the dashboard
  // 120ms crossfade — only when actually navigating, never on a data refresh
  if (label !== lastNavLabel) {
    lastNavLabel = label;
    main.classList.remove("enter"); void main.offsetWidth; main.classList.add("enter");
  }
}

// fill static [data-i18n] / [data-i18n-ph] + lang button
function applyStaticI18n() {
  document.documentElement.lang = lang;
  document.querySelectorAll("[data-i18n]").forEach((e) => e.textContent = t(e.dataset.i18n));
  $("search").placeholder = t("search_ph");
  $("lang").textContent = lang === "pl" ? "EN" : "PL";
  $("lang").setAttribute("aria-label", t("aria_lang"));
  $("theme").setAttribute("aria-label", t("aria_theme"));
  syncModeChrome(); // mode-dependent labels (CTA text, toggle title) re-localize too
}
function setLang(l) {
  lang = l; localStorage.setItem("cnv_lang", l); applyStaticI18n();
  document.dispatchEvent(new CustomEvent('cronova:langchanged'));
  renderUserChip(); // role label + logout button are built with t(), not data-i18n
  // dag/task re-render from in-memory D (no refetch) so unsaved edits survive.
  if (view === "dags") { setNav("dags"); renderDags(); } // crumb is localized now (Workflows) — refresh it too
  else if (view === "dag") renderDagPage();
  else if (view === "task") renderTaskPage();
  else if (view === "run") showRun(currentRun);
  else if (view === "wizard") renderWizard();
  else if (view === "pools") showPools();
  else if (view === "resources") renderResources(); // from in-memory RES, no refetch
  else if (view === "graph") showGraph();
  else if (view === "audit") renderAudit(); // from in-memory AUD — keeps filters + loaded pages
  else if (view === "workers") { setNav("workers"); renderWorkers(); } // crumb + table from in-memory WK, no refetch
  else if (view === "api") renderApi(); // from in-memory TOKENS, no refetch
  else if (view === "ai-providers") renderAIProviders(); // from in-memory AIP, no refetch
  else if (view === "aiwiki") renderAIWiki();
}
