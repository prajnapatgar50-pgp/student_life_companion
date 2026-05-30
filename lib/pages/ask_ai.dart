import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AskAIHelperPage extends StatefulWidget {
  const AskAIHelperPage({super.key});

  @override
  State<AskAIHelperPage> createState() => _AskAIHelperPageState();
}

class _AskAIHelperPageState extends State<AskAIHelperPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _currentMessages = []; 
  Map<String, List<Map<String, String>>> _allSavedChats = {}; 
  List<String> _pinnedChats = []; // ಪಿನ್ ಆಗಿರೋ ಚಾಟ್‌ಗಳ ಲಿಸ್ಟ್
  String? _currentChatId; 
  bool _isLoading = false;
  
  final String _apiKey = "AIzaSyDkAFJ5BKRt2z8oNJniF3U3Q8KTj2c21fk"; 
  late final GenerativeModel _model;
  ChatSession? _chatSession; 

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: 'gemini-2.5-flash', 
      apiKey: _apiKey,
      systemInstruction: Content.system(
        "You are an advanced multilingual student assistant supporting ALL global languages. "
        "Automatically detect the language and reply in the exact same language (Kannada, English, Hindi, etc.). "
        "Maintain strict conversation context."
      ),
    );
    _loadAllChatsFromMemory(); 
  }

  // 1. ಮೆಮೊರಿಯಿಂದ ಎಲ್ಲಾ ಡೇಟಾ ಲೋಡ್ ಮಾಡುವುದು (ಚಾಟ್ಸ್ ಮತ್ತು ಪಿನ್ ಲಿಸ್ಟ್)
  Future<void> _loadAllChatsFromMemory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedChatsString = prefs.getString('all_gemini_chats');
    final List<String>? savedPinned = prefs.getStringList('pinned_gemini_chats');
    
    if (savedPinned != null) {
      setState(() {
        _pinnedChats = savedPinned;
      });
    }

    if (savedChatsString != null) {
      final Map<String, dynamic> decodedMap = jsonDecode(savedChatsString);
      setState(() {
        _allSavedChats.clear();
        decodedMap.forEach((key, value) {
          List<Map<String, String>> chatMsgs = [];
          for (var msg in value) {
            chatMsgs.add({
              "role": msg["role"].toString(),
              "text": msg["text"].toString(),
            });
          }
          _allSavedChats[key] = chatMsgs;
        });
      });
    }
    
    _startNewChatSession();
  }

  void _startNewChatSession() {
    setState(() {
      _currentMessages.clear();
      _currentChatId = null; 
      _chatSession = _model.startChat(); 
    });
  }

  // 2. ಮೆಮೊರಿಗೆ ಡೇಟಾ ಸೇವ್ ಮಾಡುವುದು
  Future<void> _saveAllToMemory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('all_gemini_chats', jsonEncode(_allSavedChats));
    await prefs.setStringList('pinned_gemini_chats', _pinnedChats);
  }

  void _loadSpecificChat(String chatId) {
    List<Content> historyContent = [];
    for (var msg in _allSavedChats[chatId]!) {
      if (msg["role"] == "user") {
        historyContent.add(Content.text(msg["text"]!));
      } else {
        historyContent.add(Content.model([TextPart(msg["text"]!)]));
      }
    }

    setState(() {
      _currentChatId = chatId;
      _currentMessages.clear();
      _currentMessages.addAll(_allSavedChats[chatId]!);
      _chatSession = _model.startChat(history: historyContent); 
    });
    Navigator.pop(context); 
  }

  // 3. ಒಂದು ನಿರ್ದಿಷ್ಟ ಚಾಟ್ ಡಿಲೀಟ್ ಮಾಡಲು ಡೈಲಾಗ್ (ಲಾಂಗ್ ಪ್ರೆಸ್ ಆಪ್ಷನ್)
  void _showManageChatDialog(String chatId) {
    bool isPinned = _pinnedChats.contains(chatId);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(chatId, maxLines: 1, overflow: TextOverflow.ellipsis),
        content: const Text("Choose an action for this chat:"),
        actions: [
          // ಪಿನ್ / ಅನ್‌ಪಿನ್ ಬಟನ್
          TextButton(
            onPressed: () {
              setState(() {
                if (isPinned) {
                  _pinnedChats.remove(chatId);
                } else {
                  _pinnedChats.add(chatId);
                }
              });
              _saveAllToMemory();
              Navigator.pop(context);
            },
            child: Text(isPinned ? "Unpin Chat 📌" : "Pin Chat 📌", style: const TextStyle(color: Colors.blue)),
          ),
          // ಡಿಲೀಟ್ ಬಟನ್
          TextButton(
            onPressed: () {
              setState(() {
                _allSavedChats.remove(chatId);
                _pinnedChats.remove(chatId);
                if (_currentChatId == chatId) {
                  _startNewChatSession();
                }
              });
              _saveAllToMemory();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Chat deleted! 🗑️")),
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllChats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('all_gemini_chats');
    await prefs.remove('pinned_gemini_chats');
    setState(() {
      _allSavedChats.clear();
      _pinnedChats.clear();
      _currentMessages.clear();
      _currentChatId = null;
      _chatSession = _model.startChat();
    });
    if (mounted) {
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All chat history cleared! 🗑️")),
      );
    }
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return; 
    
    String userText = _controller.text;
    _controller.clear();

    setState(() { 
      _currentMessages.add({"role": "user", "text": userText}); 
      _isLoading = true; 
    });

  
    if (_currentChatId == null) {
      _currentChatId = userText.length > 30 ? "${userText.substring(0, 30)}..." : userText;
    }

    try {
      _chatSession ??= _model.startChat();
      final response = await _chatSession!.sendMessage(Content.text(userText));
      
      setState(() { 
        _currentMessages.add({
          "role": "bot", 
          "text": response.text ?? "No response received."
        }); 
        _allSavedChats[_currentChatId!] = List.from(_currentMessages);
      });
      
      _saveAllToMemory(); 
    } catch (e) {
      setState(() { 
        _currentMessages.add({"role": "bot", "text": "Error: Connection issue. Please try again."}); 
      });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- ಆರ್ಡರ್ ಲಾಜಿಕ್: ಮೊದಲು ಸರ್ಚ್ ಮಾಡಿದ್ದು ಕೆಳಗೆ ಹೋಗಲು ಮತ್ತು ಪಿನ್ ಆದದ್ದು ಮೇಲೆ ಬರಲು ---
    List<String> sortedKeys = _allSavedChats.keys.toList().reversed.toList(); // ಹೊಸದು ಮೇಲೆ, ಹಳೆಯದು ಕೆಳಗೆ
    
    // ಪಿನ್ ಆಗಿರೋ ಚಾಟ್‌ಗಳನ್ನು ಸಪರೇಟ್ ಮಾಡಿ ಲಿಸ್ಟ್‌ನ ಅತ್ಯಂತ ಮೇಲ್ಭಾಗಕ್ಕೆ ತರುವುದು
    List<String> pinnedList = sortedKeys.where((key) => _pinnedChats.contains(key)).toList();
    List<String> unpinnedList = sortedKeys.where((key) => !_pinnedChats.contains(key)).toList();
    List<String> finalDisplayList = [...pinnedList, ...unpinnedList];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gemini AI Helper"),
        backgroundColor: Colors.purple.shade100,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment, size: 24),
            onPressed: _startNewChatSession,
            tooltip: "New Chat",
          )
        ],
      ),
      
      drawer: Drawer(
        backgroundColor: const Color(0xFF171717), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 28),
                        SizedBox(width: 10),
                        Text("Gemini", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: Colors.white, size: 26),
                      onPressed: () {
                        Navigator.pop(context);
                        _startNewChatSession();
                      },
                    )
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Text("Recent Chats (Long Press to Pin/Delete)", style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            
            Expanded(
              child: _allSavedChats.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("No recent chats", style: TextStyle(color: Colors.grey, fontSize: 14)),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: finalDisplayList.length,
                      itemBuilder: (context, index) {
                        String keyId = finalDisplayList[index];
                        bool isSelected = keyId == _currentChatId;
                        bool isPinned = _pinnedChats.contains(keyId);
                        return ListTile(
                          leading: Icon(
                            isPinned ? Icons.push_pin : Icons.chat_bubble_outline, 
                            color: isPinned ? Colors.orangeAccent : (isSelected ? Colors.blueAccent : Colors.white70), 
                            size: 18
                          ),
                          title: Text(
                            keyId, 
                            style: TextStyle(
                              color: isSelected ? Colors.blueAccent : Colors.white, 
                              fontSize: 15, 
                              overflow: TextOverflow.ellipsis,
                              fontWeight: (isSelected || isPinned) ? FontWeight.bold : FontWeight.normal
                            ),
                          ),
                          onTap: () => _loadSpecificChat(keyId),
                          // --- ಇಲ್ಲಿ ಲಾಂಗ್ ಪ್ರೆಸ್ ಲಾಜಿಕ್ ಆಡ್ ಮಾಡಲಾಗಿದೆ ---
                          onLongPress: () => _showManageChatDialog(keyId), 
                        );
                      },
                    ),
            ),
            
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              title: const Text("Clear All Chats", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onTap: _clearAllChats,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
      
      body: Column(
        children: [
          Expanded(
            child: _currentMessages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        "Ask me anything in any language!\nYour chats will be saved in the sidebar menu. 💬",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _currentMessages.length,
                    itemBuilder: (context, index) {
                      final m = _currentMessages[index];
                      final isUser = m["role"] == "user";
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.blue.shade100 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(m["text"]!, style: const TextStyle(fontSize: 16)),
                        ),
                      );
                    },
                  ),
          ),
          
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple))),
            ),

          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "AI asking something...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: IconButton(
                    onPressed: _sendMessage, 
                    icon: const Icon(Icons.send, color: Colors.white)
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}