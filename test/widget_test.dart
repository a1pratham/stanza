import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stanza/data/mock_stanzas.dart';
import 'package:stanza/widgets/stanza_card.dart';

void main() {
  testWidgets('StanzaCard renders a story\'s category and headline',
          (WidgetTester tester) async {
        final stanza = mockStanzas.first; // category: 'INDIA'

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StanzaCard(
                stanza: stanza,
                isBookmarked: false,
                onBookmarkToggle: () {},
                onShare: () {},
                onOpenArticle: () {},
              ),
            ),
          ),
        );

        expect(find.text(stanza.category), findsOneWidget);
        expect(find.text(stanza.headline), findsOneWidget);
      });
}