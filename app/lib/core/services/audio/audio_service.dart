abstract class AudioService {
  Future<void> play(String eventName);

  Future<void> stopAll();
}
