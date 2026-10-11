// ignore_for_file: library_private_types_in_public_api
part of 'home.dart';

mixin HomeSections on _HomeStateBase {
  Widget _buildFilterBar() {
    return SliverToBoxAdapter(
      child: Align(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Row(
              children: [
                Text(
                  'Koleksi Manga',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: _selectedSortOption,
                  hint: const Text('Urutkan'),
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'a-z', child: Text('A-Z')),
                    DropdownMenuItem(value: 'z-a', child: Text('Z-A')),
                    DropdownMenuItem(value: 'ongoing', child: Text('Ongoing')),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                  ],
                  onChanged: _filterAndSort,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueReading() {
    final history =
        allManga
            .where(
              (manga) => manga.bookmark && !_removedHistory.contains(manga.id),
            )
            .take(4)
            .toList();
    if (history.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Align(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeading(
                  'Lanjutkan Membaca',
                  'Lanjutkan dari progres terakhirmu',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 104,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, index) => _historyCard(history[index]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _historyCard(Manga manga) {
    final chapter = int.tryParse(manga.chapter) ?? 45;
    final current = chapter > 1 ? (chapter * .38).round().clamp(1, chapter) : 1;
    final progress = current / chapter;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        width: 285,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _textColor.withValues(alpha: .08)),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    manga.cardImageUrl,
                    width: 58,
                    height: 78,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    cacheWidth: 116,
                    cacheHeight: 156,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        manga.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Terakhir dibaca: 2 hari lalu',
                        style: TextStyle(
                          color: _textColor.withValues(alpha: .58),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bab $current / $chapter',
                        style: TextStyle(
                          color: _textColor.withValues(alpha: .72),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              right: -7,
              top: -9,
              child: IconButton(
                tooltip: 'Hapus dari riwayat',
                icon: Icon(
                  Icons.close,
                  size: 17,
                  color: _textColor.withValues(alpha: .45),
                ),
                onPressed: () => setState(() => _removedHistory.add(manga.id)),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: -10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: _textColor.withValues(alpha: .1),
                  valueColor: const AlwaysStoppedAnimation(Color(0xfff0443e)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestAndTrending() {
    final updates = displayedManga.take(_visibleUpdates).toList();
    return SliverToBoxAdapter(
      child: Align(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 850;
                final latest = _latestUpdates(updates);
                final trending = _trendingSidebar();
                return narrow
                    ? Column(
                      children: [latest, const SizedBox(height: 20), trending],
                    )
                    : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: SizedBox(
                            width: double.infinity,
                            child: latest,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            width: double.infinity,
                            child: trending,
                          ),
                        ),
                      ],
                    );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _latestUpdates(List<Manga> updates) {
    const itemsPerGroup = 4;
    final today = updates.take(itemsPerGroup).toList();
    final yesterday = updates.skip(itemsPerGroup).take(itemsPerGroup).toList();
    final lastWeek = updates.skip(itemsPerGroup * 2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('Update Terbaru', 'Manga pilihan yang baru diperbarui'),
        const SizedBox(height: 14),
        if (updates.isEmpty)
          Text('Belum ada update manga.', style: TextStyle(color: _textColor))
        else ...[
          _updateGroup('Hari Ini', today, 0),
          if (yesterday.isNotEmpty)
            _updateGroup('Kemarin', yesterday, itemsPerGroup),
          if (lastWeek.isNotEmpty)
            _updateGroup('Minggu Lalu', lastWeek, itemsPerGroup * 2),
        ],
        if (_visibleUpdates < displayedManga.length)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: OutlinedButton(
                onPressed: () => setState(() => _visibleUpdates += 8),
                child: const Text('Muat Lebih Banyak'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _updateGroup(String title, List<Manga> manga, int indexOffset) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 520
                ? 4
                : constraints.maxWidth >= 450
                ? 3
                : constraints.maxWidth >= 300
                ? 2
                : 1;
        final cardWidth =
            (constraints.maxWidth - ((columns - 1) * 13)) / columns;
        return SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (indexOffset > 0) const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  color: _textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 9),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: manga.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 13,
                  mainAxisSpacing: 14,
                  mainAxisExtent: cardWidth * 1.5 + 68,
                ),
                itemBuilder:
                    (_, index) =>
                        _updateCard(manga[index], index + indexOffset),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _updateCard(Manga manga, int index) {
    final badge =
        index % 3 == 0
            ? 'HOT'
            : index % 3 == 1
            ? 'NEW'
            : 'END';
    final badgeColor =
        badge == 'HOT'
            ? const Color(0xffe84747)
            : badge == 'NEW'
            ? const Color(0xff4285d4)
            : const Color(0xff3ba66b);
    return Card(
      color: _surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _textColor.withValues(alpha: .07)),
      ),
      child: InkWell(
        onTap: () => _openMangaDetail(manga),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    manga.cardImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => const ColoredBox(
                          color: Colors.black12,
                          child: Icon(Icons.image_not_supported),
                        ),
                  ),
                  Positioned(
                    left: 9,
                    top: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .72),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'CH. ${manga.chapter}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 68,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 8, 11, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      manga.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1.15,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          manga.rating.toStringAsFixed(1),
                          style: TextStyle(
                            color: _textColor.withValues(alpha: .62),
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          manga.status,
                          style: TextStyle(
                            color: _textColor.withValues(alpha: .55),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendingSidebar() {
    final tabs = ['Harian', 'Mingguan', 'Bulanan'];
    return Container(
      constraints: const BoxConstraints(minHeight: 430),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _textColor.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Trending',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.local_fire_department,
                color: Colors.orange,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children:
                tabs.asMap().entries.map((entry) {
                  final active = _trendingTab == entry.key;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _trendingTab = entry.key),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Text(
                          entry.value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                active
                                    ? const Color(0xff9a5bea)
                                    : _textColor.withValues(alpha: .55),
                            fontSize: 11,
                            fontWeight:
                                active ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
          Divider(color: _textColor.withValues(alpha: .1)),
          ..._trendingManga.take(5).toList().asMap().entries.map((entry) {
            final rising = entry.key % 3 == 0;
            final stable = entry.key % 3 == 1;
            return Material(
              color: Colors.transparent,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap: () => _openMangaDetail(entry.value),
                leading: Text(
                  '${entry.key + 1}',
                  style: TextStyle(
                    color: _textColor.withValues(alpha: .55),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                title: Text(
                  entry.value.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${entry.value.view} pembaca',
                  style: TextStyle(
                    color: _textColor.withValues(alpha: .5),
                    fontSize: 10,
                  ),
                ),
                trailing: Icon(
                  stable
                      ? Icons.horizontal_rule
                      : rising
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 16,
                  color:
                      stable
                          ? Colors.grey
                          : rising
                          ? Colors.green
                          : Colors.red,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _sectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _textColor,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            color: _textColor.withValues(alpha: .55),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCuratedCollections() {
    final availableManga = _releasedManga;
    if (availableManga.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Align(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeading(
                  'MC Overpowered dari Awal',
                  '#Action  #Fantasy  #SoloLevelingVibes',
                ),
                const SizedBox(height: 12),
                Stack(
                  children: [
                    SizedBox(
                      height: 326,
                      child: ListView.separated(
                        controller: _collectionsScrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount:
                            availableManga.length > 8
                                ? 8
                                : availableManga.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder:
                            (_, index) =>
                                _collectionCard(availableManga[index]),
                      ),
                    ),
                    Positioned.fill(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Positioned(
                            left: 4,
                            top: 130,
                            child: FloatingActionButton.small(
                              heroTag: 'collection-previous',
                              onPressed: () {
                                if (!_collectionsScrollController.hasClients) {
                                  return;
                                }
                                final position =
                                    _collectionsScrollController.position;
                                final previousOffset = (position.pixels - 560)
                                    .clamp(0.0, position.maxScrollExtent);
                                _collectionsScrollController.animateTo(
                                  previousOffset,
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                              backgroundColor: Colors.black87,
                              child: const Icon(
                                Icons.chevron_left,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 130,
                            child: FloatingActionButton.small(
                              heroTag: 'collection-next',
                              onPressed: () {
                                if (!_collectionsScrollController.hasClients) {
                                  return;
                                }
                                final position =
                                    _collectionsScrollController.position;
                                final nextOffset = (position.pixels + 560).clamp(
                                  0.0,
                                  position.maxScrollExtent,
                                );
                                _collectionsScrollController.animateTo(
                                  nextOffset,
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                              backgroundColor: Colors.black87,
                              child: const Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _collectionCard(Manga manga) {
    return InkWell(
      onTap: () => _openMangaDetail(manga),
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: 170,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.network(
                manga.cardImageUrl,
                width: 170,
                height: 255,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                cacheWidth: 340,
                cacheHeight: 510,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              manga.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _textColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunitySnippets() {
    if (allManga.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    const snippets = <String>[];
    return SliverToBoxAdapter(
      child: Align(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeading(
                  'Suara Komunitas',
                  'Komentar terbaru tanpa spoiler',
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 700;
                    final cards =
                        snippets.asMap().entries.map((entry) {
                          final index = entry.key;
                          return Container(
                            height: 78,
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: const Color(0xff1e1e1e),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .08),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    allManga[index % allManga.length]
                                        .cardImageUrl,
                                    width: 44,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.low,
                                    cacheWidth: 88,
                                    cacheHeight: 112,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${entry.value}\n— Rian_IF',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList();
                    return compact
                        ? Column(
                          children: [
                            for (final card in cards) ...[
                              card,
                              const SizedBox(height: 10),
                            ],
                          ],
                        )
                        : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (
                              var index = 0;
                              index < cards.length;
                              index++
                            ) ...[
                              Expanded(child: cards[index]),
                              if (index < cards.length - 1)
                                const SizedBox(width: 12),
                            ],
                          ],
                        );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return SliverToBoxAdapter(
      child: Container(
        color: const Color(0xff0f0f0f),
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 38),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = [
              const Text(
                'Mangatsu',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Tilt',
                  fontSize: 22,
                ),
              ),
              const Text(
                'Platform baca manga nyaman dengan update terbaru setiap hari.',
                style: TextStyle(color: Colors.white60, height: 1.5),
              ),
              const Text(
                '© 2025 Mangatsu. DMCA & Hak Cipta',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const Text(
                'Tentang Kami\nHubungi Kami\nRequest Manga',
                style: TextStyle(color: Colors.white70, height: 2),
              ),
              const Text(
                'Aturan Komentar\nPrivasi\nSyarat Layanan',
                style: TextStyle(color: Colors.white70, height: 2),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _socialIcon(Icons.facebook),
                  _socialIcon(Icons.alternate_email),
                  _socialIcon(Icons.link),
                ],
              ),
            ];
            return Wrap(
              spacing: 34,
              runSpacing: 22,
              alignment: WrapAlignment.spaceBetween,
              children:
                  columns
                      .map(
                        (child) => SizedBox(
                          width: constraints.maxWidth > 850 ? 190 : 145,
                          child: child,
                        ),
                      )
                      .toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _socialIcon(IconData icon) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white12,
        child: Icon(icon, color: Colors.white70, size: 17),
      ),
    ),
  );
}
