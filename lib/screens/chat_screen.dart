// import 'package:flutter/material.dart';
// import 'package:flutter_gemma/flutter_gemma.dart';

// class ChatScreen extends StatefulWidget {
//   const ChatScreen({super.key});

//   @override
//   State<ChatScreen> createState() => _ChatScreenState();
// }

// class _ChatScreenState extends State<ChatScreen> {
//   final TextEditingController _controller = TextEditingController();
//   final ScrollController _scrollController = ScrollController();

//   InferenceModel? _model;
//   InferenceChat? _chat;

//   final List<_ChatMessage> _messages = [];
//   bool _isInitializing = true;
//   bool _isGenerating = false;
//   String? _currentResponse;
//   String? _errorMessage;

//   @override
//   void initState() {
//     super.initState();
//     _initializeModel();
//   }

//   Future<void> _initializeModel() async {
//     try {
//       // Ensure the model is marked as active — safe to call even if already installed.
//       // flutter_gemma detects the existing file and skips re-downloading.
//       await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
//           .fromNetwork(
//             'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task',
//           )
//           .install();

//       // Now create the model instance
//       final model = await FlutterGemma.getActiveModel(
//         maxTokens: 2048,
//         preferredBackend: PreferredBackend.gpu,
//         supportImage: true,
//         maxNumImages: 1,
//       );

//       // Create a chat session
//       final chat = await model.createChat(
//         temperature: 0.8,
//         topK: 40,
//         supportImage: true,
//       );

//       setState(() {
//         _model = model;
//         _chat = chat;
//         _isInitializing = false;
//       });
//     } catch (e) {
//       setState(() {
//         _isInitializing = false;
//         _errorMessage = 'Failed to load model: $e';
//       });
//     }
//   }

//   Future<void> _sendMessage() async {
//     final text = _controller.text.trim();
//     if (text.isEmpty || _isGenerating || _chat == null) return;

//     _controller.clear();

//     setState(() {
//       _messages.add(_ChatMessage(text: text, isUser: true));
//       _isGenerating = true;
//       _currentResponse = '';
//     });

//     _scrollToBottom();

//     try {
//       await _chat!.addQueryChunk(Message.text(text: text, isUser: true));

//       final buffer = StringBuffer();

//       await for (final response in _chat!.generateChatResponseAsync()) {
//         if (response is TextResponse) {
//           buffer.write(response.token);
//           if (mounted) {
//             setState(() {
//               _currentResponse = buffer.toString();
//             });
//             _scrollToBottom();
//           }
//         }
//       }

//       // Done streaming — commit final message
//       if (mounted) {
//         setState(() {
//           _messages.add(_ChatMessage(text: buffer.toString(), isUser: false));
//           _currentResponse = null;
//           _isGenerating = false;
//         });
//         _scrollToBottom();
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _messages.add(_ChatMessage(text: 'Error: $e', isUser: false));
//           _currentResponse = null;
//           _isGenerating = false;
//         });
//       }
//     }
//   }

//   void _scrollToBottom() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 200),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _chat?.close();
//     _model?.close();
//     _controller.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF0A0A0F),
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF0A0A0F),
//         elevation: 0,
//         iconTheme: const IconThemeData(color: Colors.white),
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'On-Device Chat',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 18,
//                 fontWeight: FontWeight.w700,
//               ),
//             ),
//             Row(
//               children: [
//                 Container(
//                   width: 8,
//                   height: 8,
//                   decoration: BoxDecoration(
//                     color: _isInitializing
//                         ? Colors.orange
//                         : const Color(0xFFFF5722),
//                     shape: BoxShape.circle,
//                   ),
//                 ),
//                 const SizedBox(width: 6),
//                 Text(
//                   _isInitializing
//                       ? 'Loading model...'
//                       : 'Gemma 3n E2B · on-device',
//                   style: const TextStyle(
//                     color: Colors.white54,
//                     fontSize: 10,
//                     letterSpacing: 1,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//       body: _isInitializing
//           ? _buildLoadingView()
//           : _errorMessage != null
//           ? _buildErrorView()
//           : _buildChatView(),
//     );
//   }

//   Widget _buildLoadingView() {
//     return const Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           CircularProgressIndicator(color: Color(0xFFFF5722)),
//           SizedBox(height: 20),
//           Text(
//             'Warming up the model...',
//             style: TextStyle(color: Colors.white54, fontSize: 14),
//           ),
//           SizedBox(height: 6),
//           Text(
//             'This takes a few seconds the first time',
//             style: TextStyle(color: Colors.white30, fontSize: 11),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildErrorView() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(32),
//         child: Text(
//           _errorMessage!,
//           style: const TextStyle(color: Colors.white70),
//           textAlign: TextAlign.center,
//         ),
//       ),
//     );
//   }

//   Widget _buildChatView() {
//     return Column(
//       children: [
//         Expanded(
//           child: _messages.isEmpty && _currentResponse == null
//               ? _buildEmptyState()
//               : ListView.builder(
//                   controller: _scrollController,
//                   padding: const EdgeInsets.all(16),
//                   itemCount:
//                       _messages.length + (_currentResponse != null ? 1 : 0),
//                   itemBuilder: (context, index) {
//                     if (index < _messages.length) {
//                       return _buildMessageBubble(_messages[index]);
//                     }
//                     // Streaming response (in progress)
//                     return _buildMessageBubble(
//                       _ChatMessage(text: _currentResponse ?? '', isUser: false),
//                       isStreaming: true,
//                     );
//                   },
//                 ),
//         ),
//         _buildInputBar(),
//       ],
//     );
//   }

//   Widget _buildEmptyState() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(32),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.bolt,
//               color: const Color(0xFFFF5722).withOpacity(0.7),
//               size: 48,
//             ),
//             const SizedBox(height: 16),
//             const Text(
//               'Ready when you are',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 20,
//                 fontWeight: FontWeight.w700,
//               ),
//             ),
//             const SizedBox(height: 8),
//             const Text(
//               'Ask anything. No server, no bills, no internet.',
//               style: TextStyle(color: Colors.white54, fontSize: 13),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildMessageBubble(_ChatMessage message, {bool isStreaming = false}) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 16),
//       child: Column(
//         crossAxisAlignment: message.isUser
//             ? CrossAxisAlignment.end
//             : CrossAxisAlignment.start,
//         children: [
//           Text(
//             message.isUser ? 'You' : 'Gemma',
//             style: TextStyle(
//               color: message.isUser ? Colors.white54 : const Color(0xFFFF5722),
//               fontSize: 10,
//               letterSpacing: 2,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//           const SizedBox(height: 6),
//           Container(
//             constraints: BoxConstraints(
//               maxWidth: MediaQuery.of(context).size.width * 0.8,
//             ),
//             padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//             decoration: BoxDecoration(
//               color: message.isUser
//                   ? const Color(0xFFFF5722)
//                   : Colors.white.withOpacity(0.06),
//               borderRadius: BorderRadius.circular(4),
//             ),
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 Flexible(
//                   child: Text(
//                     message.text,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 15,
//                       height: 1.4,
//                     ),
//                   ),
//                 ),
//                 if (isStreaming) ...[
//                   const SizedBox(width: 6),
//                   const _BlinkingCursor(),
//                 ],
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildInputBar() {
//     return Container(
//       decoration: const BoxDecoration(
//         border: Border(top: BorderSide(color: Colors.white10)),
//       ),
//       padding: EdgeInsets.only(
//         left: 16,
//         right: 16,
//         top: 12,
//         bottom: MediaQuery.of(context).padding.bottom + 12,
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: TextField(
//               controller: _controller,
//               enabled: !_isGenerating,
//               style: const TextStyle(color: Colors.white),
//               decoration: InputDecoration(
//                 hintText: _isGenerating ? 'Thinking...' : 'Ask anything...',
//                 hintStyle: const TextStyle(color: Colors.white38),
//                 filled: true,
//                 fillColor: Colors.white.withOpacity(0.04),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(4),
//                   borderSide: BorderSide.none,
//                 ),
//                 contentPadding: const EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 14,
//                 ),
//               ),
//               onSubmitted: (_) => _sendMessage(),
//             ),
//           ),
//           const SizedBox(width: 8),
//           Material(
//             color: _isGenerating
//                 ? Colors.white.withOpacity(0.1)
//                 : const Color(0xFFFF5722),
//             borderRadius: BorderRadius.circular(4),
//             child: InkWell(
//               borderRadius: BorderRadius.circular(4),
//               onTap: _isGenerating ? null : _sendMessage,
//               child: const Padding(
//                 padding: EdgeInsets.all(14),
//                 child: Icon(Icons.arrow_upward, color: Colors.white, size: 20),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ========= Helper classes =========

// class _ChatMessage {
//   final String text;
//   final bool isUser;

//   _ChatMessage({required this.text, required this.isUser});
// }

// class _BlinkingCursor extends StatefulWidget {
//   const _BlinkingCursor();

//   @override
//   State<_BlinkingCursor> createState() => _BlinkingCursorState();
// }

// class _BlinkingCursorState extends State<_BlinkingCursor>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 500),
//     )..repeat(reverse: true);
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FadeTransition(
//       opacity: _controller,
//       child: Container(width: 8, height: 16, color: Colors.white70),
//     );
//   }
// }


import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:image_picker/image_picker.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  InferenceModel? _model;
  InferenceChat? _chat;

  final List<_ChatMessage> _messages = [];
  bool _isInitializing = true;
  bool _isGenerating = false;
  String? _currentResponse;
  String? _errorMessage;

  // Currently attached (but not yet sent) image
  Uint8List? _pendingImage;

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    try {
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      )
          .fromNetwork(
            'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task',
          )
          .install();

      final model = await FlutterGemma.getActiveModel(
        maxTokens: 2048,
        preferredBackend: PreferredBackend.gpu,
        supportImage: true,
        maxNumImages: 1,
      );

      final chat = await model.createChat(
        temperature: 0.8,
        topK: 40,
        supportImage: true,
      );

      setState(() {
        _model = model;
        _chat = chat;
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Failed to load model: $e';
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        _pendingImage = bytes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Attach an image',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFFF5722)),
              title: const Text('Take a photo',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFFFF5722)),
              title: const Text('Choose from gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final hasImage = _pendingImage != null;

    if ((text.isEmpty && !hasImage) || _isGenerating || _chat == null) return;

    _controller.clear();

    final imageToSend = _pendingImage;

    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: true,
        image: imageToSend,
      ));
      _pendingImage = null;
      _isGenerating = true;
      _currentResponse = '';
    });

    _scrollToBottom();

    try {
      // Build message for Gemma — text + image if attached
      final Message message = hasImage
          ? Message.withImage(
              text: text.isEmpty ? 'Describe this image in detail.' : text,
              imageBytes: imageToSend!,
              isUser: true,
            )
          : Message.text(text: text, isUser: true);

      await _chat!.addQueryChunk(message);

      final buffer = StringBuffer();

      await for (final response in _chat!.generateChatResponseAsync()) {
        if (response is TextResponse) {
          buffer.write(response.token);
          if (mounted) {
            setState(() {
              _currentResponse = buffer.toString();
            });
            _scrollToBottom();
          }
        }
      }

      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(text: buffer.toString(), isUser: false));
          _currentResponse = null;
          _isGenerating = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(text: 'Error: $e', isUser: false));
          _currentResponse = null;
          _isGenerating = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _chat?.close();
    _model?.close();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'On-Device Chat',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isInitializing
                        ? Colors.orange
                        : const Color(0xFFFF5722),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isInitializing
                      ? 'Loading model...'
                      : 'Gemma 3n E2B · vision · on-device',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: _isInitializing
          ? _buildLoadingView()
          : _errorMessage != null
              ? _buildErrorView()
              : _buildChatView(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFFF5722)),
          SizedBox(height: 20),
          Text(
            'Warming up the model...',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          SizedBox(height: 6),
          Text(
            'This takes a few seconds the first time',
            style: TextStyle(color: Colors.white30, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildChatView() {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty && _currentResponse == null
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      _messages.length + (_currentResponse != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < _messages.length) {
                      return _buildMessageBubble(_messages[index]);
                    }
                    return _buildMessageBubble(
                      _ChatMessage(
                        text: _currentResponse ?? '',
                        isUser: false,
                      ),
                      isStreaming: true,
                    );
                  },
                ),
        ),
        if (_pendingImage != null) _buildPendingImagePreview(),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bolt,
              color: const Color(0xFFFF5722).withOpacity(0.7),
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ready when you are',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask a question, or attach an image\nand let Gemma describe it.',
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'No Server · No Bills · No Internet',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message, {bool isStreaming = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            message.isUser ? 'You' : 'Gemma',
            style: TextStyle(
              color: message.isUser
                  ? Colors.white54
                  : const Color(0xFFFF5722),
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (message.image != null)
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.65,
              ),
              margin: const EdgeInsets.only(bottom: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(message.image!, fit: BoxFit.cover),
              ),
            ),
          if (message.text.isNotEmpty || isStreaming)
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser
                    ? const Color(0xFFFF5722)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (isStreaming) ...[
                    const SizedBox(width: 6),
                    const _BlinkingCursor(),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingImagePreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: const Border(
          top: BorderSide(color: Colors.white10),
          bottom: BorderSide(color: Colors.white10),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.memory(
              _pendingImage!,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Image attached',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: () => setState(() => _pendingImage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      padding: EdgeInsets.only(
        left: 8,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.add_photo_alternate_outlined,
              color: _isGenerating
                  ? Colors.white24
                  : const Color(0xFFFF5722),
              size: 28,
            ),
            onPressed: _isGenerating ? null : _showImageSourcePicker,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_isGenerating,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _isGenerating
                    ? 'Thinking...'
                    : (_pendingImage != null
                        ? 'Ask about the image...'
                        : 'Ask anything...'),
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _isGenerating
                ? Colors.white.withOpacity(0.1)
                : const Color(0xFFFF5722),
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: _isGenerating ? null : _sendMessage,
              child: const Padding(
                padding: EdgeInsets.all(14),
                child:
                    Icon(Icons.arrow_upward, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========= Helper classes =========

class _ChatMessage {
  final String text;
  final bool isUser;
  final Uint8List? image;

  _ChatMessage({required this.text, required this.isUser, this.image});
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 16,
        color: Colors.white70,
      ),
    );
  }
}