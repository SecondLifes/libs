# Memory Index

- [Naming Conventions](feedback_naming.md) — Dosya prefix'i kuraldır; class isimleri kullanıcının kontrolünde
- [Refactor Decisions](feedback_refactor_decisions.md) — Dosya/modül ayrımı kararları kullanıcıya aittir
- [MD Auto-Update](feedback_md_autoupdate.md) — MD/test dosyaları her düzeltmeden sonra değil, release tamamlanınca toplu güncellenir
- [Vendor Adopt](feedback_vendor_adopt.md) — Harici kütüphane analizinde beğenilen yapılar framework'e eklenmek üzere bildirilir
- [İnceleme Dosyası Workflow](feedback_dikkat_workflow.md) — "inceleme yap" + serbest dosya adı/adları (DIKKAT.md sabit değil); belirsizse sor, iş bitince onaylı tek sonuç dosyası (<kaynak>.md) + API dokümantasyonu (örneklerle)
- [TDynArrayHashed Kullanılmıyor](project_no_more_tdynarrayhashed.md) — Yeni kodda yasak; mevcutta karşılaşılırsa kullanıcıya bildirip TDictionary'ye geçiş kararı alınır
- [DUnitX TestCase Stili](dunitx_test_style.md) — Category/TestCase/AutoNameTestCase ile data-driven test; tüm isimler (prosedür/senaryo/parametre) Türkçe
- [Delphi Compiler Quirks](project_delphi_compiler_quirks.md) — TQueue<TProc> E2010 bug (box as IInterface); bare finalization without initialization is E2029; mORMot units need -NS; closure-inside-closure loop capture broken (extract named factory method)
- [Prompt Language](feedback_prompt_language.md) — Gelen promptlar İngilizce olabilir (bilinçli); yanıtlar her zaman Türkçe
- [Test Runner](reference_test_runner.md) — src/test/run_tests.bat ile gerçek dcc32+DUnitX çalıştırma; yeni test unit'i RunTests.dpr+.dproj'a eklenmeli
- [Codegen Manual Review OK](feedback_codegen_manual_review_ok.md) — Kod üreten (string dönen) fonksiyonlarda kullanıcının elle düzeltmesi beklenir, her edge-case'i koda gömmeye çalışma
- [Teknik Israrcılık OK](feedback_teknik_israrcilik.md) — Haklıyken ısrarcı/agresif davranmak istenir; "ısrarlısın" yorumu tek başına geri çekilme sebebi değil
- [.pas UTF-8 BOM Kontrolü](project_pas_utf8_bom.md) — Türkçe karakterli yeni/düzenlenen .pas dosyalarında BOM (efbbbf) kontrol edilmeli, yoksa dcc32 karakterleri mojibake'e çevirir
