package de.purrtion.app.data

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.Update
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface EntryDao {
    @Query("SELECT * FROM entries WHERE day = :day ORDER BY createdAt DESC")
    fun observeDay(day: Long): Flow<List<FoodEntry>>

    @Query("SELECT * FROM entries WHERE day = :day ORDER BY createdAt")
    suspend fun day(day: Long): List<FoodEntry>

    @Query("SELECT * FROM entries WHERE day >= :from AND day <= :to ORDER BY day, createdAt")
    fun observeRange(from: Long, to: Long): Flow<List<FoodEntry>>

    @Query("SELECT * FROM entries WHERE day >= :from AND day <= :to ORDER BY day, createdAt")
    suspend fun range(from: Long, to: Long): List<FoodEntry>

    @Query("SELECT * FROM entries ORDER BY day, createdAt")
    suspend fun all(): List<FoodEntry>

    @Query("SELECT DISTINCT day FROM entries WHERE day >= :from")
    suspend fun loggedDays(from: Long): List<Long>

    @Query("SELECT * FROM entries WHERE id = :id")
    fun observe(id: String): Flow<FoodEntry?>

    @Query("SELECT * FROM entries WHERE id = :id")
    suspend fun get(id: String): FoodEntry?

    @Upsert suspend fun upsert(entry: FoodEntry)
    @Upsert suspend fun upsertAll(entries: List<FoodEntry>)
    @Delete suspend fun delete(entry: FoodEntry)
    @Query("DELETE FROM entries WHERE id IN (:ids)") suspend fun deleteIds(ids: List<String>)
    @Query("DELETE FROM entries") suspend fun deleteAll()
}

@Dao
interface SavedDao {
    @Query("SELECT * FROM saved ORDER BY lastUsed DESC")
    fun observeAll(): Flow<List<SavedFood>>

    @Query("SELECT * FROM saved WHERE isFavorite = 1 ORDER BY lastUsed DESC")
    fun observeFavorites(): Flow<List<SavedFood>>

    @Query("SELECT * FROM saved WHERE `key` = :key")
    fun observe(key: String): Flow<SavedFood?>

    @Query("SELECT * FROM saved WHERE `key` = :key")
    suspend fun get(key: String): SavedFood?

    @Query("SELECT * FROM saved") suspend fun all(): List<SavedFood>
    @Upsert suspend fun upsert(food: SavedFood)
    @Delete suspend fun delete(food: SavedFood)
    @Query("DELETE FROM saved") suspend fun deleteAll()
}

@Dao
interface WaterDao {
    @Query("SELECT * FROM water WHERE day = :day")
    fun observeDay(day: Long): Flow<List<WaterLog>>

    @Query("SELECT * FROM water WHERE day = :day")
    suspend fun day(day: Long): List<WaterLog>

    @Query("SELECT * FROM water WHERE day >= :from AND day <= :to")
    suspend fun range(from: Long, to: Long): List<WaterLog>

    @Query("SELECT * FROM water WHERE day >= :from AND day <= :to")
    fun observeRange(from: Long, to: Long): Flow<List<WaterLog>>

    @Query("SELECT * FROM water") suspend fun all(): List<WaterLog>
    @Insert suspend fun insert(log: WaterLog)
    @Update suspend fun update(log: WaterLog)
    @Query("DELETE FROM water") suspend fun deleteAll()
}

@Dao
interface WeightDao {
    @Query("SELECT * FROM weights ORDER BY date")
    fun observeAll(): Flow<List<WeightLog>>

    @Query("SELECT * FROM weights ORDER BY date") suspend fun all(): List<WeightLog>
    @Insert suspend fun insert(log: WeightLog)
    @Insert suspend fun insertAll(logs: List<WeightLog>)
    @Delete suspend fun delete(log: WeightLog)
    @Query("DELETE FROM weights") suspend fun deleteAll()
}

@Dao
interface CustomDao {
    @Query("SELECT * FROM custom ORDER BY name COLLATE NOCASE")
    fun observeAll(): Flow<List<CustomFood>>

    @Query("SELECT * FROM custom") suspend fun all(): List<CustomFood>
    @Query("SELECT * FROM custom WHERE id = :id") suspend fun get(id: String): CustomFood?
    @Query("SELECT * FROM custom WHERE name = :name") suspend fun byName(name: String): List<CustomFood>
    @Upsert suspend fun upsert(food: CustomFood)
    @Delete suspend fun delete(food: CustomFood)
    @Query("DELETE FROM custom") suspend fun deleteAll()
}

@Dao
interface ReviewDao {
    @Query("SELECT * FROM reviews WHERE day = :day")
    fun observeDay(day: Long): Flow<DayReview?>

    @Query("SELECT * FROM reviews WHERE day = :day") suspend fun day(day: Long): DayReview?
    @Query("SELECT * FROM reviews") suspend fun all(): List<DayReview>
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun put(review: DayReview)
    @Query("DELETE FROM reviews WHERE day = :day") suspend fun deleteDay(day: Long)
    @Query("DELETE FROM reviews") suspend fun deleteAll()
}

@Database(entities = [FoodEntry::class, SavedFood::class, WaterLog::class, WeightLog::class, CustomFood::class, DayReview::class],
    version = 1, exportSchema = true)
abstract class AppDatabase : RoomDatabase() {
    abstract fun entries(): EntryDao
    abstract fun saved(): SavedDao
    abstract fun water(): WaterDao
    abstract fun weights(): WeightDao
    abstract fun custom(): CustomDao
    abstract fun reviews(): ReviewDao

    companion object {
        fun create(context: Context): AppDatabase =
            Room.databaseBuilder(context, AppDatabase::class.java, "purrtion.db").build()
    }
}
