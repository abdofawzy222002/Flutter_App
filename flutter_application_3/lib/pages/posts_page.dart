import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PostsPage extends StatefulWidget {
  const PostsPage({super.key});

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  final _titleController = TextEditingController();
  final _imageController = TextEditingController();
  final _commentController = TextEditingController();
  final _searchController = TextEditingController();

  String _searchQuery = '';

  Future<void> _showDeleteDialog({
    required BuildContext context,
    required VoidCallback onConfirm,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this item?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); 
              },
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(); 
                onConfirm(); 
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _addPostToFirestore(String title, String imageUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userName =
        userDoc.data()?['name'] ?? user.displayName ?? user.email ?? 'Unknown';

    await FirebaseFirestore.instance.collection('posts').add({
      'title': title,
      'imageUrl': imageUrl,
      'userId': user.uid,
      'userName': userName,
      'likes': [],
      'timestamp': Timestamp.now(),
    });

    _titleController.clear();
    _imageController.clear();
  }

  void _toggleLike(String postId, List likes) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    if (likes.contains(uid)) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([uid]),
      });
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([uid]),
      });
    }
  }

  void _addComment(String postId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userName =
        userDoc.data()?['name'] ?? user.displayName ?? user.email ?? 'Unknown';

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .add({
      'text': text,
      'userName': userName,
      'userId': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _commentController.clear();
  }

  void _editPost(String postId, String oldTitle, String oldImageUrl) {
    _titleController.text = oldTitle;
    _imageController.text = oldImageUrl;

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: "Title"),
            ),
            TextField(
              controller: _imageController,
              decoration: InputDecoration(labelText: "Image URL"),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('posts')
                    .doc(postId)
                    .update({
                  'title': _titleController.text.trim(),
                  'imageUrl': _imageController.text.trim(),
                });

                _titleController.clear();
                _imageController.clear();
                Navigator.pop(context);
              },
              child: Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  void _deletePost(String postId) async {
    await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
  }

  void _editComment(String postId, String commentId, String oldText) {
    _commentController.text = oldText;
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _commentController,
              decoration: InputDecoration(labelText: "Comment"),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('posts')
                    .doc(postId)
                    .collection('comments')
                    .doc(commentId)
                    .update({'text': _commentController.text.trim()});

                _commentController.clear();
                Navigator.pop(context);
              },
              child: Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteComment(String postId, String commentId) async {
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  Widget _buildComments(String postId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('timestamp')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox();
        final comments = snapshot.data!.docs;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: comments.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final isOwner = uid == data['userId'];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.account_circle,
                      size: 30,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['userName'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(data['text'] ?? ''),
                        ],
                      ),
                    ),
                    if (isOwner)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.orange),
                            onPressed: () =>
                                _editComment(postId, doc.id, data['text']),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              _showDeleteDialog(
                                context: context,
                                onConfirm: () =>
                                    _deleteComment(postId, doc.id),
                              );
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: Colors.blue[300],
      appBar: AppBar(
        title: Text("All Posts"),
        centerTitle: true,
        backgroundColor: Colors.blue[200],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) =>
                  setState(() => _searchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search posts...',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        child: Icon(Icons.add),
        onPressed: () => showModalBottomSheet(
          context: context,
          builder: (context) => Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: Colors.white,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("New Post", style: TextStyle(fontSize: 18)),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(labelText: "Title"),
                    ),
                    TextField(
                      controller: _imageController,
                      decoration: InputDecoration(labelText: "Image URL"),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        _addPostToFirestore(
                          _titleController.text.trim(),
                          _imageController.text.trim(),
                        );
                        Navigator.pop(context);
                      },
                      child: Text("Post"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: Container(
          width: 700,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              final posts = snapshot.data?.docs ?? [];
              final filteredPosts = posts.where((post) {
                final data = post.data() as Map<String, dynamic>;
                final title = data['title']?.toLowerCase() ?? '';
                final userName = data['userName']?.toLowerCase() ?? '';
                return title.contains(_searchQuery) ||
                    userName.contains(_searchQuery);
              }).toList();

              return ListView.builder(
                itemCount: filteredPosts.length,
                itemBuilder: (_, i) {
                  final post = filteredPosts[i];
                  final data = post.data() as Map<String, dynamic>;
                  final likes = List.from(data['likes'] ?? []);
                  final postId = post.id;
                  final isOwner = uid == data['userId'];

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((data['imageUrl'] ?? '').isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Image.network(
                              data['imageUrl'],
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ListTile(
                          title: Text(
                            data['title'] ?? '',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("by ${data['userName'] ?? 'Unknown'}"),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              Column(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      likes.contains(uid)
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: Colors.red,
                                    ),
                                    onPressed: () =>
                                        _toggleLike(postId, likes),
                                  ),
                                  Text("${likes.length}"),
                                ],
                              ),
                              if (isOwner) ...[
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.orange),
                                  onPressed: () => _editPost(
                                    postId,
                                    data['title'] ?? '',
                                    data['imageUrl'] ?? '',
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    _showDeleteDialog(
                                      context: context,
                                      onConfirm: () => _deletePost(postId),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  decoration: InputDecoration(
                                    hintText: 'Write a comment...',
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.send),
                                onPressed: () => _addComment(
                                  postId,
                                  _commentController.text.trim(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildComments(postId),
                        SizedBox(height: 10),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}