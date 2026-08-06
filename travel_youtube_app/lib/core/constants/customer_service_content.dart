class FaqItem {
  final String question;
  final String answer;

  const FaqItem({required this.question, required this.answer});
}

/// Static FAQ + contact content for the customer service screen. No backend
/// call is involved — this is a purely informational screen.
class CustomerServiceContent {
  CustomerServiceContent._();

  static const List<FaqItem> faqs = [
    FaqItem(
      question: '유튜브 영상 분석이 안 돼요.',
      answer: '자막이 없는 영상은 분석할 수 없습니다. 다른 브이로그 영상으로 다시 시도해 주세요.',
    ),
    FaqItem(
      question: '동선을 만들 때 장소는 몇 개까지 선택할 수 있나요?',
      answer: '한 번에 최소 2개, 최대 10개의 장소를 선택해 동선을 만들 수 있습니다.',
    ),
    FaqItem(
      question: '시작 호텔과 종료 호텔을 다르게 설정할 수 있나요?',
      answer: '네. 같은 호텔을 선택하면 왕복 동선, 다른 호텔을 선택하면 호텔 간 이동 동선으로 자동 생성됩니다.',
    ),
    FaqItem(
      question: '하나의 여행에 여러 날짜를 저장할 수 있나요?',
      answer: '네. 여행을 만든 뒤 1일차, 2일차처럼 날짜를 추가하며, 날짜마다 시작/종료 호텔을 다르게 설정할 수 있습니다.',
    ),
    FaqItem(
      question: '북마크한 장소를 정리하고 싶어요.',
      answer: '마이페이지의 북마크 폴더 기능을 사용하면 북마크를 원하는 폴더에 담아 정리할 수 있습니다. 하나의 북마크를 여러 폴더에 담을 수도 있습니다.',
    ),
  ];

  static const String contactEmail = 'support@voylog.app';
}
