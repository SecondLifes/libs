# AI Rule: Token Strategy
Version: 1.3.0
Status: ACTIVE
Author: System Architect
Son Güncelleme: 2026-07-04

## Kapsam
Dosyalarda LLM token yönetimi ve okuma verimliliği.

## Kurallar
1. Bir Pascal dosyası okunurken satır sayısından bağımsız olarak doğrudan
   sadece `interface` bölümü okunur; `implementation` kısmına ihtiyaç
   duyulursa okumadan önce kullanıcıya onaylatılır.
2. Kod değişikliklerinde sadece değişen kısımlar (diff) sunulmalıdır.
3. 'Sadece istenen dosya' prensibi katı uygulanır. İlgisiz dizin taramaları yasaktır.
