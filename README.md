# Projektspezifikation: MaGam

## 📋 Serviceübersicht
* **Benutzerstruktur**: 1 Administrator (Hauptbereichsleiter) - 2 Zwischenmanager pro Filiale (Inhaber, Nachtschichtleiter)
* **Umfang**: Hauptbereichsleiter Yang – 9 Filialen, insgesamt 18 Zwischenmanager

> 💡 **Zusätzliche Aufgaben und Erweiterungen**
> * Anzahl der Hauptbereichsleiter erhöhen (Hinzufügen von Management-Ebenen wie Direktor und Vorstand über dem Hauptbereichsleiter)
> * Erstellung einer Position für den Vorsitzenden (President)
> * ⭐ Migration der Datenbank-E-Mails. Hinzufügung und Änderung der 1-3 DB-Struktur, Code-Anpassungen/Änderungen
> * Funktionserweiterung: Da die Menüs je nach Filiale variieren (z. B. Pizza, Steingrill), soll der Administrator filialspezifische Menüs hinzufügen können.
> * PC-Version (Desktop-Version)
> * Abschlussinhalte: Implementierung einer Suchfunktion mit bedingten Filtereinstellungen.

---

## 1. Konfiguration der Berichtsartikel

### 1️⃣ Arbeitsbeginn-Bericht (Check-in)
* **Bericht über Besonderheiten**
* **Personalstatus (Vormittag, Nachmittag, Nacht)**: z. B. Personal insgesamt 0 Personen (Inhaber 0, Metzgerei 0, Service 0, Küche 0)
* **Lebensmittelbestand**:
    * Schweinerippchen (MM/TT 0 Behälter), Galbi-tang (0 Portionen), Kimchi-Suppe (0 Portionen)
    * Geschmorte Rippchen mit Mugeonji (0 Portionen), Makrele mit Siraegi (0 Portionen), Dongchimi (MM/TT 0 Behälter), Naengmyeon
* **Qualitätskontrolle**: Prüfung von Frische, Reifegrad und Geschmack der Zutaten
* **Reservierungsstatus**: 00:00 Uhr 00 Personen

### 2️⃣ Umsatzbericht
* **Zeiträume**: Mittag, Tag, Nacht
* **Nach Kategorien**: Rippchen, Metzgerei, Take-out, Summe (jeweils 0.000.000 Won)
* **Anzahl der verkauften Speisen**

### 3️⃣ Abschlussbericht
* Freitext-Eingabe

---

## 2. Detaillierte Dateninhalte

### 📊 Umsatz und Ausgaben
* **Umsatzdetails**: Gesamtumsatz, 1. Mitarbeiter-Rabatt, 2. Bargeld, 3. Barausgaben, (1+2+3) Barumsatz, Kartenzahlung, Tagesumsatz
* **Ausgabendetails**: Makkoli u. a., Feuchttücher, Öl/LPG, Eier, Tofu, Müllsäcke, Eiscreme, Versand/Fracht/Transport, Flüssigseife/Reinigungsmittel, Aushilfskräfte (Paschul)

### 📦 Bestandsverwaltung
* **Bestandsartikel**: Schweinerippchen, König-Galbitang, Kimchi-Suppe, Geschmorte Rippchen, Siraegi-Makrele, Dongchimi, Naengmyeon, Holzkohle, Reis (erweiterbar)
* **Bestandsdetails**: Anfangsbestand, Wareneingang, Verkauf, aktueller Bestand (Geum-jae)
* **Besonderheit**: Unterscheidung zwischen POS-Bestand und tatsächlichem physischen Bestand.

### 👥 Sonstiges
* Status von Ein-/Austritten sowie Versetzungen
* Vorauszahlungen, Besonderheiten zum Abschluss
* Verfasser (Verantwortlicher)

---

## 📅 Entwicklungstagebuch

### 14.12.2025 So.
* **Repräsentative App-Farbe**: Khaki (jjdd), schwarzer Anzug, rote Krawatte
* **1. Überarbeitung**:
    * `tab_day`, `tab_sales`: Hinzufügung von Auf-/Ab-Pfeilen zur Mengenanpassung von `constants`-Artikeln.
    * Einheit: Umstellung von `int` auf `float`, um 0,5er-Schritte zu ermöglichen (Pfeiltasten bewegen sich in 1er-Schritten).
    * Anwendung der gleichen Funktion auf den Personalstatus in `tab_day`.
    * `tab_sales`: Logik zur Unterscheidung von Tag-/Nachtschicht (z. B. Nachtschichtbericht vom 14.12. wird am 15.12. um 10:00 Uhr morgens erstellt).
* **Bereichsdetails**:
    * **Teil 1 (Umsatz)**: Barrabatt, Bargeld, Barausgaben, Barumsatz, Kartenzahlung, Gesamtumsatz, Tagesumsatz.
    * **Teil 2 (Ausgaben)**: 12 Kategorien von Makkoli bis Aushilfskräfte, Sonstiges, Summe.
    * **Teil 3 (Personal)**: Eintritt, Austritt, Versetzung.
    * **Teil 4 (Notiz)**: Freitext für Vorauszahlungen/Besonderheiten.
    * **Bestand**: Anfang/Eingang/Verkauf/Aktuell/Ausschuss. Unterstützung von Dezimalstellen.
* **Hinweis**: Alle Inhalte müssen mit der DB synchronisiert sein, damit sie vom Admin-Konto in Echtzeit eingesehen werden können.

### 15.12.2025 Mo.
> 💡 **Arbeitsinhalte**
> * Logik für `tab_day`, `tab_sales`, `tab_closing` fertiggestellt
> * Funktion hinzugefügt, um Daten beim Tab-Wechsel beizubehalten
> * Funktion zum Laden von Daten bei Auswahl eines Datums
> * `records_screen`: Funktion zum Einsehen aller Aufzeichnungen
* **To-do**: DB-Struktur verbessern, Admin-Seite konzipieren, Umsatzaggregation nach Zeitraum und Filterfunktion hinzufügen.

### 16.12.2025 Di. ~ 18.12.2025 Do.
* Aufbau der Admin-Seite und Implementierung der Funktionen (Umsatz, Besonderheiten, Abschluss)
* Umsatzseite: Überblick über alle Filialumsätze und Anzeige des Gesamtumsatzes ganz oben oder unten.

### 22.12.2025 Mo.
* Detaillierung der Admin-Seite:
    * Tab 1: Anzeige der Filialnamen und Sortierung nach Umsatz (Gesamtumsatz - Tag, Nacht)
    * Beim Tippen auf eine Filiale: Anzeige aller Details (cashFlow, salesTime, staffCounts, closingNote)
    * Tab 2: Listenansicht der Aufzeichnungen nach Filiale
* **Sonstiges**: Farbanpassung der Benachrichtigung "Vormittagsbericht wurde gespeichert"

### 01.01.2026 Do.
* Admin-Details: Hinzufügung von Vormittags-Besonderheiten und Reservierungsstatus ✅
* Anpassung für neue Filialen: Guri-Hwaro (Pizza hinzugefügt), Guri-Dolpan (Ente, Chadol, rohe Ente, Jumul-reok)

### 19.01.2026 Mo. ~ 20.01.2026 Di.
* Admin-Funktion zum Bearbeiten von Manager-Einträgen hinzugefügt ✅ (Umsatzzeiträume, Kategorien, Personal, Vorbereitungsmenüs, Abschlussartikel, Ausgaben/Bestandskategorien)
* **Nächster Schritt**: Anzeige des aktuellen Status (Nicht erstellt, In Bearbeitung, Abgeschlossen) im `admin_dashboard` basierend auf dem `status`-Feld.

### 21.01.2026 Mi.
* Web-Dashboard Erstellung: Echtzeit-Status und Detailansicht fertiggestellt
* **Fehler**: Fehler beim Laden der DB in der App-Version, Login-Fehler (automatischer Admin-Login)

### 22.01.2026 Do.
* **Fokus**: Behebung der App-Fehler (Vermeidung von Änderungen an `report_service.dart`, um Auswirkungen auf das Web-Dashboard zu minimieren)
* **Zusätzliche Funktionen**: Auto-Login, monatliche/jährliche kumulierte Werte pro Filiale ✅
* **Nächster Schritt**: Behebung des Login-Fehlers nach Logout, Behebung des Datenladeproblems bei Web-Dashboard-Grafiken.

### 29.01.2026 Do.
* `[ ]` Behebung des Login-Problems
* `[ ]` Behebung der Grafik-Funktionsprobleme im Web-Dashboard

---

## 📂 Datenbank- und App-Struktur

### 🛠 Tech Stack
* **Datenbank**: Google Firebase

### 🏗 DB-Struktur
#### 1. stores
* **Sammlung**: `stores`
    * **Dokument**: `{Nutzer-UID}` (Authentifizierung)
        * **Untersammlung**: `dailyReports`
            * **Dokument**: `{yyyy-mm-dd}`
                * (Detaillierte Berichtsinhalte)

#### 2. users
* **Sammlung**: `users`
    * **Dokument**: `{Nutzer-UID}` (Authentifizierung)
    * **Felder**:
        * `email`: `storeID@magam.jjdd`
        * `role`: `manager` / `admin`
        * `storeID`: (Identifikationsmerkmal der Filiale)

===

# 프로젝트 명세서: MaGam

## 📋 서비스 개요
* **사용자 구조**: 관리자 1명 (본부장) - 매장별 중간관리자 2명 (사장, 야간실장)
* **규모**: 양본부장 - 매장 9개, 중간관리자 총 18명

> 💡 **추가 작업 및 고도화 사항**
> * 본부장 수 늘리기 (본부장 위에 상무, 전무 관리자 직급 추가)
> * 회장님 포지션 신규 작성
> * ⭐ 데이터베이스 이메일 이전, 1-3 DB 구조 추가 및 수정, 코드 수정/변경
> * 기능 추가: 매장별 메뉴 차별화 (예: 피자, 돌판) - 관리자가 매장별 메뉴를 직접 추가 가능하도록 구현
> * 컴퓨터(PC) 버전 대응
> * 마감 내용: 조건부 설정을 통한 필터링 및 검색 기능

---

## 1. 보고 항목 설정

### 1️⃣ 출근 보고
* **특이사항 보고**
* **근무인원 현황(오전, 오후, 야간)**: 예) 근무인원 총 0명 (사장 0명, 정육 0명, 홀 0명, 주방 0명)
* **음식 재고**:
    * 돼지갈비 (MM/DD일자 0통), 갈비탕(0인분), 김치찌개(0인분)
    * 등갈비묵은지찜(0인분), 시래기고등어조림(0인분), 동치미(MM/DD일자 0통), 냉면
* **품질 관리**: 식재료 신선도, 숙성도, 맛 이상 유무 체크
* **예약 현황**: 00시 00명

### 2️⃣ 매출 보고
* **시간대별**: 점심, 주간, 야간
* **항목별**: 갈비, 정육, 포장, 합계 (각 0,000,000원)
* **음식 판매 개수**

### 3️⃣ 마감 보고
* 자유 입력 방식

---

## 2. 데이터 세부 내용

### 📊 매출 및 지출
* **매출 내용**: 총매출, 1.직원할인, 2.현금, 3.현금지출, (1+2+3) 현금매출, 카드매출, 주간매출
* **지출 내용**: 막걸리 외, 물수건, 석유/LPG, 계란, 두부, 쓰레기봉투, 아이스크림, 택배/운임/교통, 물비누/세제, 파출비

### 📦 재고 관리
* **재고 항목**: 돼지갈비, 왕갈비탕, 김치찌개, 등갈비묵은찜, 시래기고등어조림, 동치미, 냉면, 숯, 쌀 (추가 가능 설정)
* **재고 내용**: 시작재고, 입고, 판매, 현재재고(금재)
* **특이사항**: 현재재고는 포스기 재고와 실재고를 구분하여 관리

### 👥 기타 항목
* 입/퇴사 및 전입/출 현황
* 선입금, 마감 특이사항
* 작성자 (책임자)

---

## 📅 개발 일지

### 2025.12.14 (So.)
* **앱 대표 색상**: 카키 (jjdd), 검은 정장, 빨간 넥타이 컨셉
* **1차 수정사항**:
    * `tab_day`, `tab_sales`: constants 아이템 조절 시 위아래 화살표를 통한 수량 조절 기능 추가
    * 수량 단위: 0.5개 단위 입력 가능하도록 `int`에서 `float`로 변경 (화살표 이동은 1단위)
    * `tab_day`의 근무 인원 현황에도 동일 기능 적용
    * `tab_sales`: 주간/야간 구분 로직 (예: 14일 야간근무 마감보고가 15일 오전 10시인 경우 대응)
* **섹션별 항목**:
    * **파트1(매출)**: 현금할인, 현금, 현금지출, 현금매출, 카드매출, 총매출, 주간매출
    * **파트2(지출)**: 막걸리 외 ~ 파출비, 기타지출, 총계 등 12개 항목
    * **파트3(인사)**: 입사, 퇴사, 전입/전출
    * **파트4(메모)**: 선입금/마감특이사항 자유 입력
    * **재고**: 시작/입고/판매/현재/파지(폐기). 소수점 입력 지원.
* **주의**: 모든 내용은 DB와 실시간 연결되어 admin 계정에서 확인 가능해야 함.

### 2025.12.15 (Mo.)
> 💡 **작업 내용**
> * `tab_day`, `tab_sales`, `tab_closing` 로직 완성
> * 탭 변경 시 입력 데이터 보존 기능 추가
> * 날짜 선택 시 해당 날짜 데이터 불러오기 기능
> * `records_screen`: 모든 기록 열람 기능
* **To-do**: DB 구조 개선, 관리자 페이지(admin) 구상, 기간별 매출 합산 및 필터링

### 2025.12.16 (Di.) ~ 12.18 (Do.)
* 어드민 페이지 구축 및 기능 구현 (매출, 특이사항, 마감)
* 매출 페이지: 모든 매장 매출 일괄 확인 및 전체 매출 합산 표시

### 2025.12.22 (Mo.)
* 어드민 페이지 상세화:
    * 1번 탭: 매장명 출력 및 매출 순 정렬 (총매출 - 주간, 야간 순)
    * 매장 터치 시 세부사항(cashFlow, salesTime, staffCounts, closingNote) 전체 표시
    * 2번 탭: 매장별 기록 리스트 뷰
* **기타**: "오전 보고서 저장" 알림 색상 수정

### 2026.01.01 (Do.)
* 어드민 상세 내역: 오전 특이사항, 예약 현황 추가 ✅
* 신규 매장 대응: 구리화로(피자 추가), 구리돌판(오리, 차돌, 생오리, 주물럭)

### 2026.01.19 (Mo.) ~ 01.20 (Di.)
* 어드민에서 매니저 항목 수정 기능 추가 ✅ (매출 시간대, 분류, 근무인원, 준비 메뉴, 결산 항목, 지출/재고 카테고리 등 전체)
* **Next**: `status: "complete"`인 목록 외에 작성 중인 상태(작성하지 않음, 작성중, 작성완료) 표시 기능 추가 예정

### 2026.01.21 (Mi.)
* 웹 대시보드 제작: 실시간 현황 및 상세보기 완료
* **이슈**: 앱 버전 DB 로드 오류 발생, 자동 로그인 오류(admin 고정) 발생

### 2026.01.22 (Do.)
* **작업 방향**: 앱 서비스 오류 우선 해결 (웹 대시보드 영향 최소화 위해 `report_service.dart` 수정 지양)
* **추가 기능**: 로그인 유지(자동 로그인), 매장 한달/매년 누계 계산 ✅
* **Next**: 로그아웃 후 재로그인 오류 해결, 웹 대시보드 그래프 데이터 로드 문제 해결

### 2026.01.29 (Do.)
* `[ ]` 로그인 문제 해결
* `[ ]` 웹 대시보드 그래프 기능 문제 해결

---

## 📂 데이터베이스 및 앱 구조

### 🛠 기술 스택
* **Database**: Google Firebase

### 🏗 DB Structure
#### 1. stores
* **Collection**: `stores`
    * **Document**: `{Nutzer-UID}` (Authentication)
        * **Sub-collection**: `dailyReports`
            * **Document**: `{yyyy-mm-dd}`
                * (보고서 상세 내용 포함)

#### 2. users
* **Collection**: `users`
    * **Document**: `{Nutzer-UID}` (Authentication)
        * **Fields**:
            * `email`: `storeID@magam.jjdd`
            * `role`: `manager` / `admin`
            * `storeID`: (해당 매장 식별자)