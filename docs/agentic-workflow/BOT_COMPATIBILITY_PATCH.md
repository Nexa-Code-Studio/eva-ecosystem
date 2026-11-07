# Bot Compatibility Patch Specifications (Optional Bot-Side Extensions)

> **Dokumen:** Spesifikasi Patch dan Ekstensi Kompatibilitas untuk Repositori `ekyaaa/dc-bot-project-management`.  
> **Status:** Rekomendasi Non-Destructive (Diterapkan di repositori bot oleh bot maintainer, bukan di repositori utama).

---

## 1. Analisis Kesenjangan (Gap Analysis)

Selama inspeksi kode sumber `dc-bot-project-management` (commit `7ae19d8`), teridentifikasi dua area kompatibilitas:

| No | Area / Komponen | Perilaku Saat Ini | Dampak | Rekomendasi Solusi |
| :---: | :--- | :--- | :--- | :--- |
| **1** | **Project Owner Binding** (`GitHubService.ts`) | Menggunakan variabel tunggal `GITHUB_OWNER` untuk kueri GraphQL Project v2 dan REST API repositori. | Jika Project v2 dibuat di bawah akun user (misal `@ekyaaa`) sedangkan repositori berada di bawah organisasi (`Nexa-Code-Studio`), kueri Project v2 akan menghasilkan `NotFoundError`. | Tambahkan variabel opsional `GITHUB_PROJECT_OWNER` dengan fallback ke `GITHUB_OWNER`. |
| **2** | **Event Router Webhook** (`NotificationService.ts`) | Hanya menangani event `issues`, `pull_request`, `workflow_run`, `check_suite`. Event `projects_v2_item` dan `issue_comment` diabaikan (`shouldSend: false`). | Perubahan status di Project board tidak mengirim push notifikasi instan ke Discord (namun tetap dapat dilihat via `/project status`). | Tambahkan handler `routeProjectItemEvent` jika tim menginginkan notifikasi push saat kartu Project berpindah kolom. |

---

## 2. Patch 1: Dukungan `GITHUB_PROJECT_OWNER` (Mengatasi Mismatch Pemilik)

### Perubahan File 1: `src/config/env.ts`

```diff
--- a/src/config/env.ts
+++ b/src/config/env.ts
@@ -124,6 +124,7 @@ export const EnvSchema = z.object({
   GITHUB_OWNER: z.string().min(1),
   GITHUB_REPOSITORY: z.string().min(1),
   GITHUB_PROJECT_NUMBER: z.coerce.number().int().positive(),
+  GITHUB_PROJECT_OWNER: z.string().min(1).optional(),
 
   // Persistence
   DATABASE_PATH: z.string().default('/data/bot.sqlite'),
```

### Perubahan File 2: `src/infrastructure/github/GitHubService.ts`

```diff
--- a/src/infrastructure/github/GitHubService.ts
+++ b/src/infrastructure/github/GitHubService.ts
@@ -49,7 +49,7 @@ interface ProjectMetadata {
 export interface GitHubServiceDependencies {
-  config: Pick<Config, 'GITHUB_OWNER' | 'GITHUB_REPOSITORY' | 'GITHUB_PROJECT_NUMBER'>;
+  config: Pick<Config, 'GITHUB_OWNER' | 'GITHUB_REPOSITORY' | 'GITHUB_PROJECT_NUMBER' | 'GITHUB_PROJECT_OWNER'>;
   gitHubAppAuth?: GitHubAppAuth;
   octokit?: CustomOctokitInstance;
 }
@@ -58,6 +58,7 @@ export class GitHubService implements IGitHubService {
   private readonly octokit: CustomOctokitInstance;
   private readonly owner: string;
   private readonly repo: string;
+  private readonly projectOwner: string;
   private readonly projectNumber: number;
 
   constructor(deps: GitHubServiceDependencies) {
     this.owner = deps.config.GITHUB_OWNER;
     this.repo = deps.config.GITHUB_REPOSITORY;
+    this.projectOwner = deps.config.GITHUB_PROJECT_OWNER ?? deps.config.GITHUB_OWNER;
     this.projectNumber = deps.config.GITHUB_PROJECT_NUMBER;
@@ -93,7 +94,7 @@ export class GitHubService implements IGitHubService {
       try {
         const orgRes: any = await this.octokit.graphql(GET_ORG_PROJECT_V2_METADATA, {
-          owner: this.owner,
+          owner: this.projectOwner,
           number: this.projectNumber,
         });
         projectData = orgRes?.organization?.projectV2;
@@ -107,7 +108,7 @@ export class GitHubService implements IGitHubService {
         try {
           const userRes: any = await this.octokit.graphql(GET_USER_PROJECT_V2_METADATA, {
-            owner: this.owner,
+            owner: this.projectOwner,
             number: this.projectNumber,
           });
           projectData = userRes?.user?.projectV2;
```

---

## 3. Patch 2: Ekstensi Router `projects_v2_item` (Opsional untuk Notifikasi Kolom)

Jika tim memutuskan ingin menerima notifikasi saat kolom kartu Project v2 berpindah (misal dari `Ready` ke `In Progress`), tambahkan ekstensi berikut pada `src/application/services/NotificationService.ts`:

```typescript
// Tambahkan pada switch(eventType) di NotificationService.ts:
case 'projects_v2_item':
  return this.routeProjectItemEvent(payload);

// Tambahkan implementasi method:
private async routeProjectItemEvent(payload: any): Promise<EventRoutingDecision> {
  const action = payload?.action;
  if (action !== 'edited' && action !== 'converted') {
    return { shouldSend: false };
  }

  const changes = payload?.changes?.field_value;
  if (!changes || changes.field_name !== 'Status') {
    return { shouldSend: false };
  }

  const fromStatus = changes.previous_value?.name ?? 'Unknown';
  const toStatus = changes.current_value?.name ?? 'Unknown';

  const embed = {
    title: `📋 Project Status Updated: ${fromStatus} ➔ ${toStatus}`,
    description: `Kartu Project item telah diperbarui ke status **${toStatus}**.`,
    color: 0x3498db,
    timestamp: new Date().toISOString(),
  };

  return {
    shouldSend: true,
    embeds: [embed],
    allowedMentions: { parse: [], users: [] },
  };
}
```

---

## 4. Cara Pengujian Patch di Repositori Bot

Setelah patch diterapkan di repositori bot:

```bash
# Jalankan test suite unit
npm test

# Periksa typecheck TypeScript
npm run build
```
