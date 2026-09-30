const mongoose = require('mongoose');

/**
 * ReceiverMapping Model
 * 
 * Maps a receiver (by receiver username) to one or more allowed senders (by sender username).
 * Only mapped senders with admin permission can be viewed by the receiver.
 */
const receiverMappingSchema = new mongoose.Schema({
  receiverUsername: {
    type: String,
    required: [true, 'Receiver username is required'],
    unique: true,
    trim: true,
    lowercase: true,
    index: true,
  },
  senderUsernames: {
    type: [String],
    default: [],
  },
  status: {
    type: String,
    enum: ['active', 'paused', 'revoked'],
    default: 'active',
    index: true,
  },
  permissions: {
    canViewLiveGps: {
      type: Boolean,
      default: true,
    },
    canViewHistory: {
      type: Boolean,
      default: true,
    },
  },
  assignedBy: {
    type: String,
    default: 'admin',
  },
  notes: {
    type: String,
    default: '',
  },
}, {
  collection: 'receiver_mappings',
  versionKey: false,
  timestamps: true,
});

module.exports = mongoose.model('ReceiverMapping', receiverMappingSchema);
