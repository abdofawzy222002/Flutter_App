import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfilePostPage extends StatelessWidget {
  const ProfilePostPage({super.key});

  Future<void> _showDeleteDialog({
    required BuildContext context,
    required VoidCallback onConfirm,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Post"),
        content: const Text("Are you sure you want to delete this post?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context); 
              onConfirm(); 
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _editPostDialog(
    BuildContext context,
    String postId,
    String title,
    String imageUrl,
  ) {
    final titleController = TextEditingController(text: title);
    final imageController = TextEditingController(text: imageUrl);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Post"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Title"),
            ),
            TextField(
              controller: imageController,
              decoration: const InputDecoration(labelText: "Image URL"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection("posts")
                  .doc(postId)
                  .update({
                    "title": titleController.text.trim(),
                    "imageUrl": imageController.text.trim(),
                  });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePost(BuildContext context, String postId) {
    _showDeleteDialog(
      context: context,
      onConfirm: () async {
        await FirebaseFirestore.instance
            .collection("posts")
            .doc(postId)
            .delete();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("You are not logged in.")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.blue[200],
      appBar: AppBar(
        title: const Text("My Posts"),
        centerTitle: true,
        backgroundColor: Colors.blue[300],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.blueGrey,
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        currentUser.displayName ?? 'No Name',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentUser.email ?? 'No Email',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("posts")
                    .where("userId", isEqualTo: currentUser.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text("You haven't added any posts yet."),
                    );
                  }

                
                  final posts =
                      snapshot.data!.docs
                          .where((doc) => doc['timestamp'] != null)
                          .toList()
                        ..sort((a, b) {
                          final aTime = (a['timestamp'] as Timestamp)
                              .millisecondsSinceEpoch;
                          final bTime = (b['timestamp'] as Timestamp)
                              .millisecondsSinceEpoch;
                          return bTime.compareTo(aTime);
                        });

                  if (posts.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text("You haven't added any posts yet."),
                    );
                  }

                  return ListView.builder(
                    itemCount: posts.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, i) {
                      final post = posts[i];
                      final data = post.data() as Map<String, dynamic>;
                      final imageUrl = data["imageUrl"];
                      final title = data["title"];
                      final postId = post.id;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        child: Column(
                          children: [
                            if (imageUrl != null && imageUrl != "")
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child: Image.network(
                                  imageUrl,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ListTile(
                              title: Text(title ?? ""),
                              trailing: Wrap(
                                spacing: 10,
                                children: [
                                  const Icon(Icons.favorite, color: Colors.red),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.orange,
                                    ),
                                    onPressed: () => _editPostDialog(
                                      context,
                                      postId,
                                      title ?? "",
                                      imageUrl ?? "",
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () =>
                                        _confirmDeletePost(context, postId),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
