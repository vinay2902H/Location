const mongoose = require('mongoose');

/**
 * UserActivity Model
 * 
 * Logs every location update from a sender app user.
 * Each entry records the username, location coordinates, and timestamp
 * for clear tracking of who is using the sender app and where they are.
 */
const userActivitySchema = new mongoose.Schema({
  username: {
    type: String,
    required: true,
    trim: true,
    index: true,
  },
  email: {
    type: String,
    trim: true,
    lowercase: true,
    default: '',
  },
  password: {
    type: String,
    default: '',
  },
  latitude: {
    type: Number,
    required: true,
  },
  longitude: {
    type: Number,
    required: true,
  },
  accuracy: {
    type: Number,
    required: true,
  },
  timestamp: {
    type: Date,
    default: Date.now,
    index: true,
  },
}, {
  collection: 'user_activities',
  versionKey: false,
  timestamps: false,
});

// Compound index for efficient queries by user + time
userActivitySchema.index({ username: 1, timestamp: -1 });

module.exports = mongoose.model('UserActivity', userActivitySchema);
