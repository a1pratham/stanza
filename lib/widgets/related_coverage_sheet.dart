import 'package:flutter/material.dart';
import '../models/related_article.dart';
import '../services/article_actions.dart';
import '../services/stanza_repository.dart';

/// PHASE 8 NEW: the "Related Coverage" bottom sheet (spec section 17),
/// triggered by swipe-left (spec section 6's originally-reserved gesture).
///
/// One shared implementation so Feed, Search and Saved all get identical
/// behavior — mirrors how ArticleActions centralizes open/share.
class RelatedCoverageSheet {
  static Future<void> show(
    BuildContext context,
    StanzaRepository repository,
    String stanzaId,
  ) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true,
      builder: (sheetContext) => _RelatedCoverageContent(
        repository: repository,
        stanzaId: stanzaId,
      ),
    );
  }
}

class _RelatedCoverageContent extends StatefulWidget {
  final StanzaRepository repository;
  final String stanzaId;

  const _RelatedCoverageContent({
    required this.repository,
    required this.stanzaId,
  });

  @override
  State<_RelatedCoverageContent> createState() => _RelatedCoverageContentState();
}

class _RelatedCoverageContentState extends State<_RelatedCoverageContent> {
  late Future<List<RelatedArticle>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchRelatedCoverage(widget.stanzaId);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Related Coverage',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Other publishers reporting this story',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<RelatedArticle>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.amberAccent),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Text(
                    "Couldn't load related coverage.",
                    style: const TextStyle(color: Colors.white54),
                  );
                }

                final items = snapshot.data ?? const [];

                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No other publishers are covering this story yet.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white12, height: 20),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return InkWell(
                        onTap: () => ArticleActions.openUrl(context, item.sourceUrl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.sourceName} · ${item.timeAgo}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
