# Rad Core | Enterprise Delphi Framework

## 🎯 Proje Vizyonu
**Rad Core**, Delphi 13.1 (Athens) üzerinde geliştirilen, kurumsal seviyede, genel amaçlı bir altyapı (base framework) projesidir. Temel amacı; spaghetti koddan arındırılmış, yüksek performanslı, ergonomik ve AI destekli bir geliştirme ekosistemi sunmaktır.

---

## 🏗️ Mimari Standartlar
- **Stability & Performance:** Kritik yollarda `mORMot2` ve `UniDAC` gibi vendor kütüphaneleri native performansıyla doğrudan kullanılır.
- **Event-Driven:** Uygulama içi tüm önemli eylemler bir Event Bus üzerinden dağıtılır; AI ajanları bu akışa abone olabilir.

---

## 📁 Klasör Hiyerarşisi (Project Map)
├── .claude\               # Claude Code proje talimatı ve kuralları
│   ├── CLAUDE.md          # Otomatik yüklenen proje talimatı (README + hafıza import)
│   └── rules\             # Operasyonel Kurallar (Versioned MD, native auto-load)
├── ai\                    # Proje Hafızası
│   └── memory\            # global.yaml, conflict-report.md (Hafıza)
├── docs\                  # Mimari dokümanlar ve kullanım kılavuzları
├── src\                   # ANA KAYNAK KODLAR ve PROJE YÖNETİM
│   ├── core\              # rad.* ve help.* (Framework çekirdeği)
│   ├── component\         # Tasarlanan Delphi component'lerinin kayıtlı olduğu yer
│   ├── share\             # Component editor ve ortak paylaşılan form/datamodül gibi bileşenler (alt klasör ayrımı yok)
│   ├── packages\          # Delphi paket dosyaları (*.dpk, *.dproj)
│   ├── bin\               # Derleme çıktıları (Output)
│   ├── vendor\            # Harici (3rd-party) kütüphaneler (mORMot2, UniDAC, OmniThreadLibrary, vb.)
│   └── test\              # Test altyapısı (DUnitX unit/)

---

## 🤖 AI Onboarding (Okuma Sırası)
AI Ajanı (Claude vb.) projeye dahil olduğunda dosyaları şu sırayla okumalıdır:
1. `README.md` (Mimari Anayasa ve Vizyon)
2. `ai/memory/global.yaml` (Güncel Proje Durumu ve Hafıza)
3. `.claude/rules/*.md` (Kod yazım ve inceleme kuralları — Claude Code'da otomatik yüklenir)

---

## 🛠️ Çalışma Prensipleri
- **Uzman İş Birliği:** Bu proje bir Kıdemli Mimarlar (User & AI) ortaklığıdır.
- **Clean Code:** SOLID, DRY ve YAGNI prensipleri esastır.
- **Vendor-First:** Doğrudan vendor kullanımı esastır; test ve dokümantasyon tüm işlemler bitince, onay alınarak eklenir.
