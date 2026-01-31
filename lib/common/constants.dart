// lib/common/constants.dart

import 'package:flutter/material.dart';

const Color khakiMain = Color(0xFF4F5D2F);
const Color khakiLight = Color(0xFF8D9965);
const Color brownbear = Color(0xFF7F6244);
const Color taupelight = Color(0xFFB38B6D);
const Color desertgray = Color(0xFFB8A487);
const Color dullbrown = Color(0xFF876E4B);

const Map<String, dynamic> kDefaultStoreConfig = {
  // 1. ClosingTab(마감결산)용 기존 항목
  'sales': ['직원할인', '현금', '현금지출'],
  'expenses': [
    '막걸리 외', '물수건', '석유/LPG', '계란', '두부',
    '식빵', '아이스크림', '택배/교통', '세제/비누', '파출비', '기타 지출'
  ],

  // 2. 공통 재고/메뉴 항목
  'menu': kMenuItems,

  // 3. SalesTab(매출보고)에서 추출한 전용 항목 🚀
  'salesTime': ['점심', '주간', '야간'],
  'salesCategory': ['갈비', '정육', '포장'],

  // 4. 오전보고 근무인원현황
  'dayStaff': ['사장', '정육', '홀', '주방'],

  // 5. 오전 보고용 메뉴 (이름과 유통기한 관리 여부)
  'morningMenu': [
    {'name': '돼지갈비', 'hasExpiry': true},
    {'name': '왕갈비탕', 'hasExpiry': false},
    {'name': '김치찌개', 'hasExpiry': false},
    {'name': '등갈비묵은지찜', 'hasExpiry': false},
    {'name': '시래기고등어조림', 'hasExpiry': false},
    {'name': '동치미', 'hasExpiry': true},
    {'name': '냉면', 'hasExpiry': false},
  ],
};

// 1. 매장 ID (DB 저장용 - 영어)
const List<String> kStoreIds = [
  'manan',   // 만안
  'guwol',   // 구월
  'songdo',  // 송도
  'sungui',  // 숭의
  'beomgye', // 범계
  'mansu',   // 만수
  'juan',    // 주안
  'namdong', // 남동
  'seogu',   // 서구
  'guri', // 구리
];

// 2. 매장 이름 (화면 표시용 - 한글)
// ID와 순서가 정확히 일치해야 합니다.
const Map<String, String> kStoreNames = {
  'manan': '만안점',
  'guwol': '구월점',
  'songdo': '송도점',
  'sungui': '숭의점',
  'beomgye': '범계점',
  'mansu': '만수점',
  'juan': '주안점',
  'namdong': '남동점',
  'seogu': '서구점',
  'guri': '구리점',
};

// 3. 재고 관리 품목 (추후 관리자 앱에서 추가 가능하도록 설계하겠지만, 초기값 설정)
const List<String> kMenuItems = [
  '돼지갈비',
  '왕갈비탕',
  '김치찌개',
  '등갈비묵은지찜',
  '시래기고등어조림',
  '동치미',
  '냉면',
  '숯',
  '쌀',
];