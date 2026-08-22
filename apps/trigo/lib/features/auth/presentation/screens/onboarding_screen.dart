import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class _ShowcasePage {
  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  final List<String> highlights;

  const _ShowcasePage({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    required this.highlights,
  });
}

const _showcasePages = [
  _ShowcasePage(
    icon: Icons.route_rounded,
    accent: Color(0xFF10B981),
    title: 'Book in Seconds',
    body: 'Set your pickup and drop-off, and find nearby trikes ready to take '
        'you where you need to go.',
    highlights: ['Nearby trikes', 'Instant booking'],
  ),
  _ShowcasePage(
    icon: Icons.person_search_rounded,
    accent: Color(0xFF2563EB),
    title: 'Choose Your Driver',
    body: 'Compare drivers by rating, fare estimate, and arrival time — then '
        'ride with the one you prefer.',
    highlights: ['Verified drivers', 'Ratings & ETA'],
  ),
  _ShowcasePage(
    icon: Icons.navigation_rounded,
    accent: Color(0xFF6366F1),
    title: 'Track Your Ride Live',
    body: 'Follow your driver on the map from pickup to drop-off with updates '
        'at every step of the journey.',
    highlights: ['Live updates', 'Door-to-door'],
  ),
  _ShowcasePage(
    icon: Icons.electric_rickshaw,
    accent: Color(0xFFF97316),
    title: 'Drive & Earn',
    body: 'Go online whenever you want, accept ride requests around you, and '
        'watch your earnings add up.',
    highlights: ['Flexible hours', 'Daily earnings'],
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _pageIndex = 0;

  // Feature pages + final brand page
  int get _lastPageIndex => _showcasePages.length;

  bool get _isLastPage => _pageIndex == _lastPageIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLastPage) {
      _goTo('/register/passenger');
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goTo(String location) async {
    if (mounted) context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _pageIndex = index),
                children: [
                  for (final page in _showcasePages) _buildFeaturePage(page),
                  _buildBrandPage(),
                ],
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!_isLastPage)
            TextButton(
              onPressed: () => _pageController.jumpToPage(_lastPageIndex),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF94A3B8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            )
          else
            const SizedBox(width: 64),
        ],
      ),
    );
  }

  Widget _buildFeaturePage(_ShowcasePage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 168,
                  height: 168,
                  decoration: BoxDecoration(
                    color: page.accent.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    color: page.accent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(page.icon, size: 48, color: page.accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final highlight in page.highlights)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: page.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 14, color: page.accent),
                      const SizedBox(width: 6),
                      Text(
                        highlight,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: page.accent.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF34D399), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.electric_rickshaw,
                  size: 56,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Welcome to TriGo',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your tricycle ride, one tap away.\nHow would you like to start?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i <= _lastPageIndex; i++) _buildDot(i),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLastPage) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _goTo('/register/passenger'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: const Color(0xFFBFDBFE),
                ),
                child: const Text(
                  'GET STARTED',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            TextButton(
              onPressed: () => _goTo('/register/driver'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF94A3B8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: const Text(
                'I am registering as a driver',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: const Color(0xFFBFDBFE),
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Already have an account?',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              TextButton(
                onPressed: () => _goTo('/login'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Log in',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    final isActive = index == _pageIndex;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
