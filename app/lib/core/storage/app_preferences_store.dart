abstract class AppPreferencesStore {
  Future<int?> readBestLevel();

  Future<void> writeBestLevel(int level);

  Future<bool?> readSoundEnabled();

  Future<void> writeSoundEnabled(bool enabled);

  Future<bool?> readHapticsEnabled();

  Future<void> writeHapticsEnabled(bool enabled);

  Future<int?> readSchemaVersion();

  Future<void> writeSchemaVersion(int version);
}
