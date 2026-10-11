// ignore_for_file: library_private_types_in_public_api
part of 'home.dart';

mixin HomeView on _HomeStateBase {
  Widget _errorState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off_rounded, size: 52, color: _textColor),
        const SizedBox(height: 12),
        Text('Gagal memuat manga', style: TextStyle(color: _textColor)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _loadManga, child: const Text('Coba lagi')),
      ],
    ),
  );

  Widget _buildHeader() {
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      backgroundColor:
          _isDark ? const Color(0xff15151b) : const Color(0xff17131d),
      toolbarHeight: 76,
      titleSpacing: 18,
      title: Row(
        children: [
          Image.asset('assets/logo/LogoM1.png', width: 42, height: 42),
          const SizedBox(width: 8),
          const Text(
            'angaTsu',
            style: TextStyle(
              fontFamily: 'Tilt',
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder:
                    (context, value, child) => TextField(
                      controller: _searchController,
                      onSubmitted: _search,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Cari judul manga, author, atau genre...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: .6),
                        ),
                        prefixIcon: IconButton(
                          tooltip: 'Cari',
                          onPressed: () => _search(_searchController.text),
                          icon: const Icon(Icons.search, color: Colors.white70),
                        ),
                        suffixIcon:
                            value.text.isEmpty
                                ? null
                                : IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white70,
                                  ),
                                  onPressed: _searchController.clear,
                                ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: .12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Rak buku',
          onPressed: _openLibrary,
          icon: const Icon(
            Icons.collections_bookmark_outlined,
            color: Colors.white,
          ),
        ),
        IconButton(
          tooltip:
              _isDark
                  ? 'Mode gelap'
                  : _isSepia
                  ? 'Mode sepia'
                  : 'Mode terang',
          onPressed: _cycleAppearance,
          icon: ValueListenableBuilder<int>(
            valueListenable: appearanceController,
            builder: (context, appearance, _) {
              return Icon(
                appearance == 1
                    ? Icons.dark_mode
                    : appearance == 2
                    ? Icons.auto_awesome
                    : Icons.light_mode,
                color: Colors.white,
              );
            },
          ),
        ),
        IconButton(
          tooltip: 'Profil',
          onPressed:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => Profil()),
              ),
          icon: const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xffd3a7ff),
            child: Icon(Icons.person, color: Color(0xff30203e), size: 20),
          ),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white.withValues(alpha: .08)),
      ),
    );
  }

  Widget _buildSearchDropdown() {
    return SliverToBoxAdapter(
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchController,
        builder: (context, value, child) {
          final results = _searchResults;
          if (results.isEmpty) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.fromLTRB(120, 8, 120, 0),
            constraints: const BoxConstraints(maxWidth: 620),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 18),
              ],
            ),
            child: Column(children: results.map(_searchResultTile).toList()),
          );
        },
      ),
    );
  }

  Widget _searchResultTile(Manga manga) {
    return ListTile(
      onTap: () {
        _searchController.text = manga.title;
        _openMangaDetail(manga);
      },
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image.network(
          manga.cardImageUrl,
          width: 38,
          height: 48,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          cacheWidth: 76,
          cacheHeight: 96,
        ),
      ),
      title: Text(
        manga.title,
        style: TextStyle(color: _textColor, fontWeight: FontWeight.w700),
      ),
      trailing: _statusBadge(manga.status),
    );
  }

  Widget _statusBadge(String status) {
    final ongoing = status.toLowerCase() == 'ongoing';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (ongoing ? Colors.green : Colors.blue).withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: ongoing ? Colors.green.shade700 : Colors.blue.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildCategoryMenu() {
    const categories = [
      'For You',
      'Latest Updates',
      'Trending This Week',
      'Genres',
      'Surprise Me!',
    ];
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 26),
          itemBuilder:
              (context, index) => Center(
                child: InkWell(
                  onTap: () {
                    if (categories[index] == 'Genres') {
                      Navigator.pushNamed(context, '/genres');
                      return;
                    }
                    if (categories[index] == 'Surprise Me!' &&
                        _releasedManga.isNotEmpty) {
                      setState(
                        () =>
                            _heroIndex.value =
                                (_heroIndex.value + 1) % _releasedManga.length,
                      );
                    }
                  },
                  child: Text(
                    categories[index],
                    style: TextStyle(
                      color: const Color(0xff7950b5),
                      fontWeight:
                          index == 0 ? FontWeight.w800 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }
}
