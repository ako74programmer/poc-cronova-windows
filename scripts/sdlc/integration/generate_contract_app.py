#!/usr/bin/env python3
"""Generate the supported Item API implementation from the repository contract.

This generator deliberately supports the small Item API described by
contracts/openapi.yaml. It fails closed when the contract drifts from the
operations or schemas implemented by the templates below.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from urllib.parse import urlsplit


def fail(message: str) -> None:
    raise SystemExit(f"OpenAPI/Item API validation failed: {message}")


def operation_block(lines: list[str], path: str, method: str) -> str:
    path_marker = f"  {path}:"
    try:
        path_index = lines.index(path_marker)
    except ValueError:
        fail(f"missing path {path}")
    path_end = len(lines)
    for index in range(path_index + 1, len(lines)):
        line = lines[index]
        if line.strip() and len(line) - len(line.lstrip()) <= 2:
            path_end = index
            break
    method_marker = f"    {method.lower()}:"
    try:
        method_index = lines.index(method_marker, path_index + 1, path_end)
    except ValueError:
        fail(f"missing {method.upper()} operation for {path}")
    method_end = path_end
    for index in range(method_index + 1, path_end):
        line = lines[index]
        if line.strip() and len(line) - len(line.lstrip()) <= 4:
            method_end = index
            break
    return "\n".join(lines[method_index:method_end])


def require_patterns(block: str, description: str, patterns: list[str]) -> None:
    for pattern in patterns:
        if not re.search(pattern, block, re.MULTILINE):
            fail(f"{description} must contain {pattern!r}")


def validate_contract(contract: Path) -> None:
    if not contract.is_file():
        fail(f"contract not found: {contract}")
    text = contract.read_text(encoding="utf-8")
    lines = text.splitlines()
    require_patterns(text, "OpenAPI document", [r"^openapi:\s*3\.0\.3\s*$", r"^paths:\s*$", r"^components:\s*$"])
    actual_paths = re.findall(r"^  (/[^:]+):$", text, re.MULTILINE)
    expected_paths = ["/api/items", "/api/items/{id}"]
    if actual_paths != expected_paths:
        fail(f"implemented paths must be exactly {expected_paths}; found {actual_paths}")

    collection_get = operation_block(lines, "/api/items", "get")
    require_patterns(collection_get, "GET /api/items", [r"operationId:\s*listItems", r"'200':", r"type:\s*array", r"\$ref:\s*'#\/components\/schemas\/Item'"])

    collection_post = operation_block(lines, "/api/items", "post")
    require_patterns(collection_post, "POST /api/items", [r"operationId:\s*createItem", r"requestBody:", r"required:\s*true", r"\$ref:\s*'#\/components\/schemas\/ItemRequest'", r"'201':", r"\$ref:\s*'#\/components\/schemas\/Item'", r"'400':"])

    item_get = operation_block(lines, "/api/items/{id}", "get")
    require_patterns(item_get, "GET /api/items/{id}", [r"operationId:\s*getItem", r"'200':", r"\$ref:\s*'#\/components\/schemas\/Item'", r"'404':"])

    item_put = operation_block(lines, "/api/items/{id}", "put")
    require_patterns(item_put, "PUT /api/items/{id}", [r"operationId:\s*updateItem", r"requestBody:", r"required:\s*true", r"\$ref:\s*'#\/components\/schemas\/ItemRequest'", r"'200':", r"\$ref:\s*'#\/components\/schemas\/Item'", r"'400':", r"'404':"])

    item_delete = operation_block(lines, "/api/items/{id}", "delete")
    require_patterns(item_delete, "DELETE /api/items/{id}", [r"operationId:\s*deleteItem", r"'204':", r"'404':"])

    parameter_section = text.split("  parameters:", 1)[-1].split("  schemas:", 1)[0]
    require_patterns(parameter_section, "ItemId parameter", [
        r"(?ms)^    ItemId:\n.*?^      name:\s*id",
        r"(?ms)^    ItemId:\n.*?^      in:\s*path",
        r"(?ms)^    ItemId:\n.*?^      required:\s*true",
        r"(?ms)^    ItemId:\n.*?^        type:\s*integer\n        format:\s*int64",
    ])

    required_operations = {
        ("/api/items", "get"), ("/api/items", "post"),
        ("/api/items/{id}", "get"), ("/api/items/{id}", "put"),
        ("/api/items/{id}", "delete"),
    }
    actual_operations: set[tuple[str, str]] = set()
    for path in ("/api/items", "/api/items/{id}"):
        path_index = lines.index(f"  {path}:")
        path_end = next((i for i in range(path_index + 1, len(lines)) if lines[i].strip() and len(lines[i]) - len(lines[i].lstrip()) <= 2), len(lines))
        for line in lines[path_index + 1:path_end]:
            match = re.fullmatch(r"    (get|post|put|delete):", line)
            if match:
                actual_operations.add((path, match.group(1)))
    if actual_operations != required_operations:
        fail(f"implemented operations must be exactly {sorted(required_operations)}; found {sorted(actual_operations)}")

    require_patterns(text, "Item schema", [
        r"(?ms)^    Item:\n.*?^      required:\s*\[id,\s*name\]",
        r"(?ms)^    Item:\n.*?^        id:\n          type:\s*integer\n          format:\s*int64",
        r"(?ms)^    Item:\n.*?^        name:\n          type:\s*string",
    ])
    require_patterns(text, "ItemRequest schema", [
        r"(?ms)^    ItemRequest:\n.*?^      required:\s*\[name\]",
        r"(?ms)^    ItemRequest:\n.*?^        name:\n          type:\s*string\n          minLength:\s*1",
    ])
    print(f"Item API contract is valid: {contract}")


JAVA_SOURCES = {
    "Item.java": """package __PACKAGE__;

public record Item(long id, String name) { }
""",
    "ItemRequest.java": """package __PACKAGE__;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record ItemRequest(
    @NotNull @Size(min = 1) String name
) { }
""",
    "ItemService.java": """package __PACKAGE__;

import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.stereotype.Service;

@Service
public class ItemService {
    private final AtomicLong nextId = new AtomicLong(1);
    private final ConcurrentMap<Long, Item> items = new ConcurrentHashMap<>();

    public List<Item> list() {
        return items.values().stream().sorted(Comparator.comparingLong(Item::id)).toList();
    }

    public Optional<Item> get(long id) {
        return Optional.ofNullable(items.get(id));
    }

    public Item create(String name) {
        Item item = new Item(nextId.getAndIncrement(), name);
        items.put(item.id(), item);
        return item;
    }

    public Optional<Item> update(long id, String name) {
        return Optional.ofNullable(items.computeIfPresent(id, (key, current) -> new Item(id, name)));
    }

    public boolean delete(long id) {
        return items.remove(id) != null;
    }
}
""",
    "ItemController.java": """package __PACKAGE__;

import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/items")
@CrossOrigin(origins = "${app.cors.allowed-origin:http://127.0.0.1:4300}")
public class ItemController {
    private final ItemService items;

    public ItemController(ItemService items) {
        this.items = items;
    }

    @GetMapping
    public List<Item> listItems() {
        return items.list();
    }

    @PostMapping
    public ResponseEntity<Item> createItem(@Valid @RequestBody ItemRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(items.create(request.name()));
    }

    @GetMapping("/{id}")
    public ResponseEntity<Item> getItem(@PathVariable long id) {
        return items.get(id).map(ResponseEntity::ok).orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}")
    public ResponseEntity<Item> updateItem(@PathVariable long id, @Valid @RequestBody ItemRequest request) {
        return items.update(id, request.name()).map(ResponseEntity::ok).orElseGet(() -> ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteItem(@PathVariable long id) {
        return items.delete(id) ? ResponseEntity.noContent().build() : ResponseEntity.notFound().build();
    }
}
""",
    "ItemServiceTest.java": """package __PACKAGE__;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class ItemServiceTest {
    private ItemService items;

    @BeforeEach
    void setUp() {
        items = new ItemService();
    }

    @Test
    void supportsCreateReadUpdateAndDelete() {
        Item created = items.create("first");
        assertEquals(new Item(created.id(), "first"), items.get(created.id()).orElseThrow());
        assertEquals(new Item(created.id(), "renamed"), items.update(created.id(), "renamed").orElseThrow());
        assertEquals("renamed", items.list().getFirst().name());
        assertTrue(items.delete(created.id()));
        assertFalse(items.get(created.id()).isPresent());
        assertFalse(items.delete(created.id()));
    }

    @Test
    void updateMissingItemReturnsEmpty() {
        assertTrue(items.update(999L, "missing").isEmpty());
    }
}
""",
}

ANGULAR_SERVICE = """import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface Item {
  id: number;
  name: string;
}

export type ItemRequest = Pick<Item, 'name'>;

@Injectable({ providedIn: 'root' })
export class ItemApiService {
  private readonly http = inject(HttpClient);
  private readonly itemsUrl = `${__API_BASE_URL__}/items`;

  listItems(): Observable<Item[]> {
    return this.http.get<Item[]>(this.itemsUrl);
  }

  getItem(id: number): Observable<Item> {
    return this.http.get<Item>(`${this.itemsUrl}/${id}`);
  }

  createItem(request: ItemRequest): Observable<Item> {
    return this.http.post<Item>(this.itemsUrl, request);
  }

  updateItem(id: number, request: ItemRequest): Observable<Item> {
    return this.http.put<Item>(`${this.itemsUrl}/${id}`, request);
  }

  deleteItem(id: number): Observable<void> {
    return this.http.delete<void>(`${this.itemsUrl}/${id}`);
  }
}
"""

ANGULAR_APP = """import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Item, ItemApiService } from './item-api.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [FormsModule],
  template: `
    <main>
      <header>
        <h1>Item Portal</h1>
        <p>Manage items through the Spring Boot Item API.</p>
      </header>

      <form aria-label="Create item" (ngSubmit)="createItem()">
        <label for="new-item-name">Item name</label>
        <input id="new-item-name" name="newItemName" [(ngModel)]="newItemName" required minlength="1" />
        <button type="submit" [disabled]="!newItemName.trim()">Create item</button>
      </form>

      @if (error) {
        <p role="alert">{{ error }}</p>
      }

      <section aria-labelledby="items-heading">
        <h2 id="items-heading">Items</h2>
        <ul>
          @for (item of items; track item.id) {
            <li>
              <span>{{ item.name }}</span>
              <button type="button" (click)="viewItem(item.id)">View {{ item.name }}</button>
              <button type="button" (click)="beginEdit(item)">Edit {{ item.name }}</button>
              <button type="button" (click)="deleteItem(item)">Delete {{ item.name }}</button>
            </li>
          } @empty {
            <li>No items yet</li>
          }
        </ul>
      </section>

      @if (selectedItem) {
        <section aria-label="Selected item">
          <h2>Selected item</h2>
          <p>ID: <span data-testid="selected-item-id">{{ selectedItem.id }}</span></p>
          <p>Name: <span data-testid="selected-item-name">{{ selectedItem.name }}</span></p>
        </section>
      }

      @if (editingId !== null) {
        <form aria-label="Edit item" (ngSubmit)="saveEdit()">
          <label for="edit-item-name">Updated item name</label>
          <input id="edit-item-name" name="editItemName" [(ngModel)]="editName" required minlength="1" />
          <button type="submit" [disabled]="!editName.trim()">Update item</button>
          <button type="button" (click)="cancelEdit()">Cancel</button>
        </form>
      }
    </main>
  `,
})
export class App implements OnInit {
  private readonly api = inject(ItemApiService);
  items: Item[] = [];
  selectedItem: Item | null = null;
  newItemName = '';
  editName = '';
  editingId: number | null = null;
  error = '';

  ngOnInit(): void {
    this.refreshItems();
  }

  refreshItems(): void {
    this.api.listItems().subscribe({
      next: (items) => { this.items = items; this.error = ''; },
      error: () => { this.error = 'Could not load items from the API.'; },
    });
  }

  createItem(): void {
    const name = this.newItemName.trim();
    if (!name) return;
    this.api.createItem({ name }).subscribe({
      next: () => { this.newItemName = ''; this.refreshItems(); },
      error: () => { this.error = 'Could not create the item.'; },
    });
  }

  viewItem(id: number): void {
    this.api.getItem(id).subscribe({
      next: (item) => { this.selectedItem = item; this.error = ''; },
      error: () => { this.error = 'Could not load the selected item.'; },
    });
  }

  beginEdit(item: Item): void {
    this.editingId = item.id;
    this.editName = item.name;
  }

  saveEdit(): void {
    if (this.editingId === null || !this.editName.trim()) return;
    const id = this.editingId;
    this.api.updateItem(id, { name: this.editName.trim() }).subscribe({
      next: (item) => {
        this.editingId = null;
        this.selectedItem = item;
        this.refreshItems();
      },
      error: () => { this.error = 'Could not update the item.'; },
    });
  }

  cancelEdit(): void {
    this.editingId = null;
    this.editName = '';
  }

  deleteItem(item: Item): void {
    this.api.deleteItem(item.id).subscribe({
      next: () => {
        this.items = this.items.filter((candidate) => candidate.id !== item.id);
        if (this.selectedItem?.id === item.id) this.selectedItem = null;
        if (this.editingId === item.id) this.cancelEdit();
        this.error = '';
      },
      error: () => { this.error = 'Could not delete the item.'; },
    });
  }
}
"""


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")
    print(f"Generated {path}")


def generate(args: argparse.Namespace) -> None:
    contract = Path(args.contract).resolve()
    validate_contract(contract)
    backend = Path(args.backend_workspace).resolve()
    frontend = Path(args.frontend_workspace).resolve()
    if not (backend / "pom.xml").is_file():
        fail(f"Spring Boot scaffold is missing pom.xml: {backend}")
    if not (frontend / "package.json").is_file():
        fail(f"Angular scaffold is missing package.json: {frontend}")
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*", args.backend_package):
        fail(f"invalid Java package name: {args.backend_package}")
    api_url = urlsplit(args.api_base_url)
    if api_url.scheme not in ("http", "https") or not api_url.netloc or api_url.path.rstrip("/") != "/api":
        fail("Angular api.base_url must be an HTTP(S) URL with the Item API /api prefix")
    frontend_url = urlsplit(args.frontend_origin)
    if frontend_url.scheme not in ("http", "https") or not frontend_url.netloc or frontend_url.path not in ("", "/") or frontend_url.query or frontend_url.fragment:
        fail("Fullstack services.frontend_url must be an HTTP(S) origin URL")

    java_package = args.backend_package.replace(".", "/")
    java_dir = backend / "src/main/java" / java_package
    for filename, content in JAVA_SOURCES.items():
        write_file(java_dir / filename, content.replace("__PACKAGE__", args.backend_package))

    resources = backend / "src/main/resources"
    write_file(resources / "application-e2e.yml", f"""app:
  cors:
    allowed-origin: \"{args.frontend_origin}\"
""")

    app_candidates = [frontend / "src/app/app.ts", frontend / "src/app/app.component.ts"]
    app_file = next((path for path in app_candidates if path.is_file()), None)
    if app_file is None:
        fail(f"could not locate Angular root component in {frontend / 'src/app'}")
    app_config = frontend / "src/app/app.config.ts"
    if not app_config.is_file():
        fail(f"Angular standalone provider config not found: {app_config}")
    config_text = app_config.read_text(encoding="utf-8")
    if not re.search(r"\bprovideHttpClient\s*\(", config_text):
        if not re.search(r"providers\s*:\s*\[", config_text):
            fail(f"Angular app.config.ts has no providers array: {app_config}")
        config_text = "import { provideHttpClient } from '@angular/common/http';\n" + config_text
        config_text, count = re.subn(r"(providers\s*:\s*\[)", r"\1provideHttpClient(), ", config_text, count=1)
        if count != 1:
            fail(f"could not add HttpClient provider to {app_config}")
        write_file(app_config, config_text)

    api_base = args.api_base_url.rstrip("/")
    service_text = ANGULAR_SERVICE.replace("__API_BASE_URL__", repr(api_base))
    write_file(frontend / "src/app/item-api.service.ts", service_text)
    write_file(app_file, ANGULAR_APP)

    app_spec_candidates = [
        frontend / "src/app" / (app_file.stem + ".spec.ts"),
        frontend / "src/app/app.spec.ts",
        frontend / "src/app/app.component.spec.ts",
    ]
    spec_file = next((path for path in app_spec_candidates if path.is_file()), None)
    if spec_file is None:
        fail(f"could not locate Angular root component unit test in {frontend / 'src/app'}")
    relative_module = "./" + app_file.stem
    spec = f"""import {{ TestBed }} from '@angular/core/testing';
import {{ of }} from 'rxjs';
import {{ App }} from '{relative_module}';
import {{ ItemApiService }} from './item-api.service';

describe('App', () => {{
  it('renders the Item Portal and loads items through the API service', async () => {{
    const api = {{
      listItems: () => of([]),
      getItem: () => of({{ id: 1, name: 'Sample item' }}),
      createItem: () => of({{ id: 1, name: 'Sample item' }}),
      updateItem: () => of({{ id: 1, name: 'Updated item' }}),
      deleteItem: () => of(void 0),
    }};
    await TestBed.configureTestingModule({{
      imports: [App],
      providers: [{{ provide: ItemApiService, useValue: api }}],
    }}).compileComponents();
    const fixture = TestBed.createComponent(App);
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('h1')?.textContent).toContain('Item Portal');
    expect(fixture.nativeElement.textContent).toContain('No items yet');
  }});
}});
"""
    write_file(spec_file, spec)
    print(f"Item CRUD application generated from {contract}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--backend-workspace")
    parser.add_argument("--frontend-workspace")
    parser.add_argument("--backend-package")
    parser.add_argument("--api-base-url")
    parser.add_argument("--frontend-origin")
    args = parser.parse_args()
    if not all((args.backend_workspace, args.frontend_workspace, args.backend_package, args.api_base_url, args.frontend_origin)):
        validate_contract(Path(args.contract).resolve())
        return
    generate(args)


if __name__ == "__main__":
    try:
        main()
    except OSError as error:
        print(f"Generator failed: {error}", file=sys.stderr)
        raise SystemExit(60)
