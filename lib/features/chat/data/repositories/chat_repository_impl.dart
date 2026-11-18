import 'package:dartz/dartz.dart';

import 'package:instagram_clone/core/error/exceptions.dart';
import 'package:instagram_clone/core/error/failures.dart';
import 'package:instagram_clone/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:instagram_clone/features/chat/domain/entities/chat.dart';
import 'package:instagram_clone/features/chat/domain/entities/message.dart';
import 'package:instagram_clone/features/chat/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remoteDataSource;

  ChatRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Chat>>> getChats(String userId) async {
    try {
      final chats = await remoteDataSource.getChats(userId);
      return Right(chats);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Chat>> getOrCreateChat(
      String currentUserId, String otherUserId) async {
    try {
      final chat =
          await remoteDataSource.getOrCreateChat(currentUserId, otherUserId);
      return Right(chat);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Message>>> getMessages(String chatId) async {
    try {
      final messages = await remoteDataSource.getMessages(chatId);
      return Right(messages);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> markMessagesAsRead(
      String chatId, String userId) async {
    try {
      final result = await remoteDataSource.markMessagesAsRead(chatId, userId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Message>> sendMessage(
      String chatId, String senderId, String receiverId, String content) async {
    try {
      final message = await remoteDataSource.sendMessage(
          chatId, senderId, receiverId, content);
      return Right(message);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Chat>> getChatById(String chatId) async {
    try {
      return Right(await remoteDataSource.getChatById(chatId));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<Either<Failure, List<Chat>>> subscribeToChats(String userId) {
    return _asResults(remoteDataSource.subscribeToChats(userId));
  }

  @override
  Stream<Either<Failure, Message>> subscribeToMessages(String chatId) {
    return _asResults(remoteDataSource.subscribeToMessages(chatId));
  }

  Stream<Either<Failure, T>> _asResults<T>(Stream<T> stream) async* {
    try {
      await for (final value in stream) {
        yield Right(value);
      }
    } on ServerException catch (error) {
      yield Left(ServerFailure(message: error.message));
    } catch (_) {
      yield const Left(
          ServerFailure(message: 'Chat connection was interrupted.'));
    }
  }
}
