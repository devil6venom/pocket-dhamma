import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/verses.dart';
import '../models/chapters.dart';
import 'package:dhammapada/screens/verse_screen.dart';
import 'package:dhammapada/screens/saved_verses_screen.dart';
import 'package:dhammapada/screens/history_screen.dart';
import 'package:dhammapada/screens/settings_screen.dart';
import 'package:provider/provider.dart';
import '../providers/verse_tracker_provider.dart';

class VersesAndChapters {
  final List<Verse> verses;
  final Map<int, Chapter> chapters;

  VersesAndChapters(this.verses, this.chapters);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late Future<VersesAndChapters> _futureVersesAndChapters;
  final PageController _pageController = PageController();

  int _selectedIndex = 0;
  int _selectedChapterId = 1;
  String _verseInput = '';
  int _sliderPage = 0;

  late AnimationController _floatingController;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();

    _futureVersesAndChapters = Future.wait([_loadVerses(), _loadChapters()])
        .then(
          (results) => VersesAndChapters(
            results[0] as List<Verse>,
            results[1] as Map<int, Chapter>,
          ),
        );

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _floatingAnimation = Tween<double>(begin: 0, end: 15).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  Future<List<Verse>> _loadVerses() async {
    final jsonString = await rootBundle.loadString('assets/verses.json');
    final data = json.decode(jsonString) as Map<String, dynamic>;
    return data.entries.map((e) => Verse.fromJson(e.key, e.value)).toList();
  }

  Future<Map<int, Chapter>> _loadChapters() async {
    final jsonString = await rootBundle.loadString('assets/chapters.json');
    final data = json.decode(jsonString) as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(int.parse(k), Chapter.fromJson(k, v)));
  }

  Widget _buildSliderPage(List<Verse> verses, Map<int, Chapter> chapterMap) {
    final tracker = Provider.of<VerseTrackerProvider>(context, listen: false);
    final lastViewed = tracker.getLastViewed();
    final chapterIds = chapterMap.keys.toList()..sort();
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final leftContent = SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          GestureDetector(
            onTap: () {
              _floatingController.repeat(reverse: true);
              Future.delayed(_floatingController.duration! * 4, () {
                _floatingController.stop();
                _floatingController.reset();
                setState(() {});
              });
            },
            child: AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -_floatingAnimation.value),
                  child: child,
                );
              },
              child: Center(
                child: Image.asset(
                  'assets/icon.png',
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 50),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: ElevatedButton.icon(
              icon: Icon(
                lastViewed == null ? Icons.auto_awesome : Icons.history,
              ),
              label: Text(
                lastViewed == null ? 'Start anew' : 'Continue where you left',
                textAlign: TextAlign.center,
              ),
              onPressed: () async {
                if (lastViewed != null) {
                  if (lastViewed.verseId != null) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VerseScreen(
                          chapterMap: chapterMap,
                          initialVerseId: int.parse(lastViewed.verseId!),
                        ),
                      ),
                    );
                  } else {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VerseScreen(
                          chapterMap: chapterMap,
                          initialChapterId: lastViewed.chapterId,
                          initialVerseId: 1,
                        ),
                      ),
                    );
                  }
                } else {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VerseScreen(
                        chapterMap: chapterMap,
                        initialChapterId: 1,
                        initialVerseId: 1,
                      ),
                    ),
                  );
                }
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.shuffle),
              label: const Text('Random Verse', textAlign: TextAlign.center),
              onPressed: () async {
                final random = (verses.toList()..shuffle()).first;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VerseScreen(
                      chapterMap: chapterMap,
                      initialVerseId: int.parse(random.id),
                    ),
                  ),
                );
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );

    final rightContent = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 500),
          child: PageView(
            onPageChanged: (i) => setState(() => _sliderPage = i),
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        child: DropdownButton<int>(
                          value: _selectedChapterId,
                          isExpanded: true,
                          onChanged: (val) =>
                              setState(() => _selectedChapterId = val!),
                          selectedItemBuilder: (context) =>
                              chapterIds.map((id) {
                                final chapter = chapterMap[id]!;
                                return Center(
                                  child: Text('$id. ${chapter.english}'),
                                );
                              }).toList(),
                          items: chapterIds.map((id) {
                            final chapter = chapterMap[id]!;
                            return DropdownMenuItem(
                              value: id,
                              child: Text('$id. ${chapter.english}'),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VerseScreen(
                                chapterMap: chapterMap,
                                initialChapterId: _selectedChapterId,
                                initialVerseId: 1,
                              ),
                            ),
                          );
                        },
                        child: const Text('Go to Chapter'),
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        child: TextField(
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            label: Center(child: Text('Verse Number')),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => _verseInput = val,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                        onPressed: () async {
                          final targetVerse = int.tryParse(_verseInput) ?? 0;
                          if (targetVerse <= 0) return;
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VerseScreen(
                                chapterMap: chapterMap,
                                initialVerseId: targetVerse,
                              ),
                            ),
                          );
                        },
                        child: const Text('Go to Verse'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (index) {
            final isActive = _sliderPage == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 8 : 6,
              height: isActive ? 8 : 6,
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ],
    );

    if (isLandscape) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(flex: 4, child: leftContent),
              const SizedBox(width: 40),
              Flexible(flex: 5, child: rightContent),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: ListView(
          shrinkWrap: true,
          children: [
            Column(children: [leftContent, rightContent]),
          ],
        ),
      ),
    );
  }

  Widget _buildScaffold(List<Verse> verses, Map<int, Chapter> chapters) {
    _selectedChapterId = chapters.containsKey(_selectedChapterId)
        ? _selectedChapterId
        : chapters.keys.first;

    const titles = ['Chapters', 'Saved Verses', 'History', 'Settings'];
    const icons = [Icons.book, Icons.bookmark, Icons.history, Icons.settings];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        centerTitle: true,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(titles[_selectedIndex]),
        ),
      ),

      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _selectedIndex = index),
        children: [
          _buildSliderPage(verses, chapters),
          SavedVersesScreen(chapterMap: chapters),
          HistoryScreen(chapterMap: chapters),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isSelected = _selectedIndex == index;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedIndex = index);
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Padding(
                padding: EdgeInsetsGeometry.symmetric(horizontal: 20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withAlpha(38)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icons[index],
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    size: 28,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VersesAndChapters>(
      future: _futureVersesAndChapters,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final verses = snapshot.data!.verses;
        final chapters = snapshot.data!.chapters;
        return _buildScaffold(verses, chapters);
      },
    );
  }
}
