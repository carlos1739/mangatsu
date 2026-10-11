import 'package:flutter/material.dart';
import 'package:project_manga/models/manga.dart';
import 'package:project_manga/widgets/anime_grid.dart';

class MangaByTitle extends StatelessWidget {
  final String title;
  final List<Manga> komikS;

  const MangaByTitle({super.key, required this.title, required this.komikS});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xff101014);
    const surface = Color(0xff1c1c23);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: const Color(0xff171719),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Hasil Pencarian',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Color(0xffb77cff)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Hasil untuk “$title”',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${komikS.length} manga',
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (komikS.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.white38),
                      SizedBox(height: 14),
                      Text(
                        'Manga tidak ditemukan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Coba gunakan judul atau kata kunci lain.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            AnimeGrid(komik: komikS),
        ],
      ),
    );
  }
}
