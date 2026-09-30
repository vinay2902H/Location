const mongoose = require('mongoose');

/**
 * User Model
 * 
 * Stores user credentials and profile details.
 * Provides a structured schema for registered senders in MongoDB.
 */
const userSchema = new mongoose.Schema({
  email: {
    type: String,
    required: [true, 'Email is required'],
    unique: true,
    trim: true,
    lowercase: true,
    index: true,
  },
  username: {
    type: String,
    required: [true, 'Username is required'],
    trim: true,
    index: true,
  },
  password: {
    type: String,
    required: [true, 'Password is required'],
  },
  lastLogin: {
    type: Date,
    default: Date.now,
  },
  lastLocation: {
    latitude: Number,
    longitude: Number,
    accuracy: Number,
    timestamp: Date,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  updatedAt: {
    type: Date,
    default: Date.now,
  },
}, {
  collection: 'users',
  versionKey: false,
  timestamps: true,
});

module.exports = mongoose.model('User', userSchema);
