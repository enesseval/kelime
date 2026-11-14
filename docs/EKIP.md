# Ekip: tek sohbet, beş rol

Sen yalnızca lead ile konuşursun. Lead işi dağıtır, sonuçları toplar ve sana tek özet verir.
Kurallar `CLAUDE.md` dosyasında, roller `.claude/agents/` klasöründe.

| Rol | Nerede çalışır | Ne yapar |
|---|---|---|
| Lead (`kelime-lead`) | Mac, ana Claude Code oturumu | Planlar, dağıtır, raporlar |
| `ios-dev` | Mac, lead çağırır | iOS kodu |
| `content` | Mac, lead çağırır | Instagram içerikleri (`marketing/instagram`) |
| `researcher` | Mac, lead çağırır | Rakip, pazar ve özellik araştırması (Gemini + web) |
| Android (`kelime-android`) | Windows, ayrı Claude Code oturumu | Android kodu |

Ortak hafıza repodur: `docs/SYNC.md` (açık eşitlemeler), `docs/SYNC_ARCHIVE.md` (kapananlar),
`docs/V1_1_PLAN.md` (ortak özellik planı). Oturum kapansa da iş buradan devam eder.

## İlk kurulum (bir kez)

İki makinede de aynı claude.ai hesabıyla giriş yapılmış olmalı (API anahtarıyla olmaz).

### Mac
1. `claude --version` yaz; 2.1.225 ya da üstü olmalı. Eskiyse `claude update`.
2. Repo klasöründe: `git fetch origin && git checkout v1.1.1 && git pull`.
3. `claude --remote-control` ile oturumu aç, içinde `/rename kelime-lead` yaz.
4. `/agents` yaz: `ios-dev`, `content` ve `researcher` listede görünmeli.

### Windows
1. `claude --version` yaz; 2.1.234 ya da üstü olmalı. Eskiyse `claude update`.
2. Repo klasöründe: `git fetch origin && git checkout v1.1.1 && git pull`.
3. Repo kökünde (`android/` içinde değil) `claude --remote-control` ile oturumu aç, içinde
   `/rename kelime-android` yaz.

### Bağlantı denemesi
1. Mac'teki lead oturumunda `/list-agents` yaz. `kelime-android` satırı "Remote Control"
   etiketiyle görünmeli.
2. Lead'e şunu yaz: "kelime-android oturumuna 'bağlantı denemesi, tek satırla cevap ver' diye
   mesaj at." Cevap geldiyse zincir çalışıyor.

### Telefon
Claude uygulamasında ya da claude.ai/code adresinde `kelime-lead` oturumunu aç. Yazdığın her şey
Mac'teki oturuma gider; Mac açık ve oturum çalışıyor olmalı.

### Gemini (isteğe bağlı, yalnızca araştırma)
`researcher` rolü Mac'te Antigravity CLI kuruluysa Gemini'ye de sorar, kurulu değilse yalnızca
web araması yapar. Kurmak için Mac'te `curl -fsSL https://antigravity.google/cli/install.sh | bash`,
sonra bir kez `agy` yazıp Google hesabınla giriş yap. Gemini kod yazmaz.

## Her gün

1. Mac'te ve Windows'ta oturumları aç (yukarıdaki 3. adımlar). İkisi de açılışta dalı çeker ve
   "Bekleyen eşitleme: N madde" ya da "Eşit" der.
2. İsteğini lead'e yaz. Örnekler:
   - "Seri sayfasına paylaş düğmesi ekle, iki platformda da."
   - "Gelecek haftanın Instagram programını hazırla."
   - "Rakiplerin son güncellemelerinde ne değişmiş, araştır."
3. Lead iş bitince tek özet verir: her platformda ne değişti, ne açık kaldı, senden ne gerekiyor.

Build, arşiv, mağazaya yükleme ve Instagram paylaşımı senin isteğinle ve senin elinle olur.

## Kota (Claude Pro)

- iOS ve Android aynı anda kod yazarken ikisi de aynı kotadan harcar.
- Rol dosyalarının başındaki `model:` satırı o rolün modelini belirler (`sonnet`, `haiku`).
  Bir rol yetersiz kalırsa o satırı değiştirmen yeter.
- Uzayan oturumda `/clear` yaz; durum repoda olduğu için bir şey kaybolmaz.

## Sorun çıkarsa

- **`kelime-android` listede yok:** Windows oturumu açık mı, `/remote-control` bağlı mı, iki
  makine aynı hesapta mı? Olmuyorsa iş durmaz: lead maddeyi `docs/SYNC.md` içinde Android `[ ]`
  olarak bırakır, Android oturumu açılışta kendisi alır.
- **Mesaj gitti ama cevap yok:** Windows oturumunda izin sorusu bekliyor olabilir; oraya bak.
- **Roller görünmüyor:** Mac'te `v1.1.1` dalında mısın, `.claude/agents/` klasörü geldi mi?
- **İki taraf aynı dosyayı değiştirdi:** `git pull --rebase` çakışma gösterir. Klasör sahipliği
  (`CLAUDE.md` tablosu) buna karşıdır; çakışan dosya çoğunlukla `docs/SYNC.md` olur, iki maddeyi
  de tutarak çözülür.
