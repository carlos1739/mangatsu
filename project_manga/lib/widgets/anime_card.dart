import 'package:flutter/material.dart';
import 'package:project_manga/models/manga.dart';
import 'package:project_manga/services/api_service.dart';

class AnimeCard extends StatefulWidget {
  final Manga anime;
  final VoidCallback? onTap;
  final bool checkBookmark;

  const AnimeCard({
    super.key,
    required this.anime,
    this.onTap,
    this.checkBookmark = false,
  });

  @override
  State<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends State<AnimeCard> {
  late bool isBookmarked;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    isBookmarked = widget.anime.bookmark;
    if (widget.checkBookmark) {
      _checkBookmark();
    }
  }

  Future<void> _checkBookmark() async {
    try {
      final bookmarked = await ApiService.isBookmarked(widget.anime.id);
      if (!mounted) return;
      setState(() {
        isBookmarked = bookmarked;
      });
    } catch (e) {
      debugPrint('Error checking bookmark: $e');
    }
  }

  Future<void> _toggleBookmark() async {
    try {
      setState(() => isLoading = true);
      
      if (isBookmarked) {
        await ApiService.removeBookmark(widget.anime.id);
      } else {
        await ApiService.addBookmark(widget.anime);
      }
      
      setState(() {
        isBookmarked = !isBookmarked;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBookmarked ? 'Added to bookmarks' : 'Removed from bookmarks',
          ),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    child: Image.network(
                      widget.anime.cardImageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.low,
                      cacheWidth: 480,
                      cacheHeight: 720,
                      errorBuilder:
                          (context, error, stackTrace) => const Center(
                            child: Icon(Icons.error, color: Colors.red),
                          ),
                      ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.anime.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(widget.anime.rating.toString()),
                          const Spacer(),
                          Text(
                            'Ch. ${widget.anime.chapter}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bookmark button
          Positioned(
            top: 8,
            right: 8,
            child: isLoading
                ? CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _toggleBookmark,
                      icon: Icon(
                        isBookmarked ? Icons.favorite : Icons.favorite_border,
                        color: isBookmarked ? Colors.red : Colors.white,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}