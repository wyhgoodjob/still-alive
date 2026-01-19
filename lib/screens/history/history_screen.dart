import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/check_in.dart';
import '../../repositories/check_in_repository.dart';

/// History screen showing past check-ins with pagination
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final CheckInRepository _checkInRepo = CheckInRepository();
  final ScrollController _scrollController = ScrollController();
  
  List<CheckIn> _checkIns = [];
  int _totalCount = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _checkIns = [];
      _hasMore = true;
    });
    
    try {
      final checkIns = await _checkInRepo.getHistory(limit: _pageSize, offset: 0);
      final count = await _checkInRepo.getCheckInCount();
      
      setState(() {
        _checkIns = checkIns;
        _totalCount = count;
        _hasMore = checkIns.length >= _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
        );
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMore) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      final moreCheckIns = await _checkInRepo.getHistory(
        limit: _pageSize,
        offset: _checkIns.length,
      );
      
      setState(() {
        _checkIns.addAll(moreCheckIns);
        _hasMore = moreCheckIns.length >= _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in History'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              child: _checkIns.isEmpty ? _buildEmptyState() : _buildHistoryList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No check-ins yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your check-in history will appear here',
              style: TextStyle(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    // Group check-ins by date
    final groupedCheckIns = _groupByDate(_checkIns);
    
    return Column(
      children: [
        // Stats header
        _buildStatsHeader(),
        const Divider(height: 1),
        // List
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: groupedCheckIns.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= groupedCheckIns.length) {
                return _buildLoadingIndicator();
              }
              
              final entry = groupedCheckIns.entries.elementAt(index);
              return _buildDateGroup(entry.key, entry.value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.green.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total Check-ins', _totalCount.toString(), Icons.check_circle),
          _buildStatItem(
            'First Check-in',
            _checkIns.isNotEmpty 
                ? DateFormat('MMM d').format(_checkIns.last.checkInTime)
                : '-',
            Icons.flag,
          ),
          _buildStatItem(
            'Last Check-in',
            _checkIns.isNotEmpty 
                ? _formatTimeAgo(_checkIns.first.checkInTime)
                : '-',
            Icons.access_time,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.green.shade700, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.green.shade800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDateGroup(String dateStr, List<CheckIn> checkIns) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Text(
            dateStr,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        // Check-ins for this date
        ...checkIns.map((checkIn) => _buildCheckInTile(checkIn)),
      ],
    );
  }

  Widget _buildCheckInTile(CheckIn checkIn) {
    final timeFormat = DateFormat('h:mm a');
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green.shade100,
        child: Icon(
          Icons.check,
          color: Colors.green.shade700,
          size: 20,
        ),
      ),
      title: Text(timeFormat.format(checkIn.checkInTime)),
      subtitle: Text(
        _getMethodLabel(checkIn.method),
        style: TextStyle(color: Colors.grey.shade600),
      ),
      trailing: Text(
        _formatTimeAgo(checkIn.checkInTime),
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Map<String, List<CheckIn>> _groupByDate(List<CheckIn> checkIns) {
    final Map<String, List<CheckIn>> grouped = {};
    
    for (final checkIn in checkIns) {
      final dateStr = _formatDateHeader(checkIn.checkInTime);
      grouped.putIfAbsent(dateStr, () => []).add(checkIn);
    }
    
    return grouped;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkInDate = DateTime(date.year, date.month, date.day);
    
    if (checkInDate == today) {
      return 'Today';
    } else if (checkInDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date); // Day name (e.g., "Monday")
    } else {
      return DateFormat('MMMM d, y').format(date); // Full date
    }
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  String _getMethodLabel(String method) {
    switch (method) {
      case 'manual':
        return 'Manual check-in';
      case 'notification':
        return 'From notification';
      case 'widget':
        return 'From widget';
      default:
        return method;
    }
  }
}
