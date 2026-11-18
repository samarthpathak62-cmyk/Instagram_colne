import 'dart:async';

import 'package:instagram_clone/core/constants/supabase_constants.dart';
import 'package:instagram_clone/core/error/exceptions.dart';
import 'package:instagram_clone/features/auth/data/models/user_model.dart';
import 'package:instagram_clone/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:instagram_clone/features/chat/data/models/chat_model.dart';
import 'package:instagram_clone/features/chat/data/models/message_model.dart';
import 'package:instagram_clone/features/chat/domain/entities/chat.dart';
import 'package:instagram_clone/features/chat/domain/entities/message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final SupabaseClient supabaseClient;

  ChatRemoteDataSourceImpl({required this.supabaseClient});

  static const _chatColumns =
      'id,user1_id,user2_id,last_message_time,has_unread_messages,'
      'first_user:users!chats_user1_id_fkey(${SupabaseConstants.publicUserColumns}),'
      'second_user:users!chats_user2_id_fkey(${SupabaseConstants.publicUserColumns})';

  ChatModel _readChat(Map<String, dynamic> row, String? viewerId) {
    final other =
        row[row['user1_id'] == viewerId ? 'second_user' : 'first_user']
            as Map<String, dynamic>?;
    return ChatModel.fromJson(row,
        otherUser: other == null ? null : UserModel.fromJson(other));
  }

  @override
  Future<Chat> getChatById(String chatId) async {
    try {
      final row = await supabaseClient
          .from('chats')
          .select(_chatColumns)
          .eq('id', chatId)
          .single();
      return _readChat(row, supabaseClient.auth.currentUser?.id);
    } on PostgrestException catch (error) {
      throw ServerException(message: 'Could not load chat: ${error.message}');
    }
  }

  @override
  Future<List<Chat>> getChats(String userId) async {
    try {
      final rows = await supabaseClient
          .from('chats')
          .select('$_chatColumns,unread:messages(count)')
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .eq('unread.receiver_id', userId)
          .eq('unread.is_read', false)
          .order('last_message_time', ascending: false);
      return rows.map((row) {
        final counts = row['unread'] as List;
        row['has_unread_messages'] =
            counts.isNotEmpty && (counts.first['count'] as int) > 0;
        return _readChat(row, userId);
      }).toList();
    } on PostgrestException catch (error) {
      throw ServerException(message: 'Could not load chats: ${error.message}');
    }
  }

  @override
  Future<Chat> getOrCreateChat(String currentUserId, String otherUserId) async {
    if (currentUserId == otherUserId) {
      throw ServerException(message: 'Choose another person to start a chat.');
    }
    try {
      // Look for a pre-existing chat in either order. Store new pairs in the
      // same order on all platforms so the unique key handles simultaneous starts.
      final ids = [currentUserId, otherUserId]..sort();
      Future<Map<String, dynamic>?> existingChat() async => supabaseClient
          .from('chats')
          .select(_chatColumns)
          .or('and(user1_id.eq.${ids[0]},user2_id.eq.${ids[1]}),and(user1_id.eq.${ids[1]},user2_id.eq.${ids[0]})')
          .order('last_message_time', ascending: false)
          .limit(1)
          .maybeSingle();

      final existing = await existingChat();
      if (existing != null) return _readChat(existing, currentUserId);
      try {
        final row = await supabaseClient
            .from('chats')
            .insert({
              'user1_id': ids[0],
              'user2_id': ids[1],
            })
            .select(_chatColumns)
            .single();
        return _readChat(row, currentUserId);
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
        final row = await existingChat();
        if (row == null) rethrow;
        return _readChat(row, currentUserId);
      }
    } on PostgrestException catch (error) {
      throw ServerException(message: 'Could not open chat: ${error.message}');
    }
  }

  @override
  Future<List<Message>> getMessages(String chatId) async {
    try {
      final rows = await supabaseClient
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .order('timestamp', ascending: true);
      return rows.map(MessageModel.fromJson).toList();
    } on PostgrestException catch (error) {
      throw ServerException(
          message: 'Could not load messages: ${error.message}');
    }
  }

  @override
  Future<bool> markMessagesAsRead(String chatId, String userId) async {
    try {
      await supabaseClient
          .from('messages')
          .update({'is_read': true})
          .eq('chat_id', chatId)
          .eq('receiver_id', userId)
          .eq('is_read', false);
      return true;
    } on PostgrestException catch (error) {
      throw ServerException(
          message: 'Could not mark messages read: ${error.message}');
    }
  }

  @override
  Future<Message> sendMessage(
      String chatId, String senderId, String receiverId, String content) async {
    try {
      final row = await supabaseClient
          .from('messages')
          .insert({
            'chat_id': chatId,
            'sender_id': senderId,
            'receiver_id': receiverId,
            'content': content,
          })
          .select()
          .single();
      return MessageModel.fromJson(row);
    } on PostgrestException catch (error) {
      throw ServerException(
          message: 'Could not send message: ${error.message}');
    }
  }

  @override
  Stream<List<Chat>> subscribeToChats(String userId) {
    // Supabase RLS limits the snapshot and events to the viewer's chats. Use
    // each change to reload joined profile fields and per-recipient unread counts.
    return supabaseClient
        .from('chats')
        .stream(primaryKey: ['id']).asyncMap((_) => getChats(userId));
  }

  @override
  Stream<Message> subscribeToMessages(String chatId) {
    final controller = StreamController<Message>();
    final channel = supabaseClient.channel('direct-messages:$chatId');
    var cancelled = false;
    controller.onListen = () {
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'chat_id',
                value: chatId),
            callback: (payload) {
              if (!cancelled)
                controller.add(MessageModel.fromJson(payload.newRecord));
            },
          )
          .subscribe();
    };
    controller.onCancel = () async {
      cancelled = true;
      await supabaseClient.removeChannel(channel);
    };
    return controller.stream;
  }
}
