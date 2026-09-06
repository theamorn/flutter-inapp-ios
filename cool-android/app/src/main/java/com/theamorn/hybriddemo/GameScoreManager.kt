package com.theamorn.hybriddemo

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue

/**
 * Tracks the highest score achieved by the user in the Flappy Cat mini-game.
 * State is observable by Jetpack Compose and persisted in SharedPreferences.
 */
object GameScoreManager {
    private const val PREFS_NAME = "game_scores"
    private const val KEY_HIGHEST_SCORE = "flappy_cat_highest_score"

    var highestScore by mutableIntStateOf(0)
        private set

    fun init(context: Context) {
        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        highestScore = prefs.getInt(KEY_HIGHEST_SCORE, 0)
    }

    fun updateScore(context: Context, score: Int) {
        if (score > highestScore) {
            highestScore = score
            val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putInt(KEY_HIGHEST_SCORE, score).apply()
        }
    }
}
