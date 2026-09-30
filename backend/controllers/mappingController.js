const ReceiverMapping = require('../models/ReceiverMapping');
const mongoose = require('mongoose');

// In-memory fallback cache when MongoDB is offline
const inMemoryMappings = new Map();
exports.inMemoryMappings = inMemoryMappings;

/**
 * Format mapping document for API response
 */
function formatMapping(doc) {
  if (!doc) return null;
  return {
    _id: doc._id ? doc._id.toString() : (doc.id ? doc.id.toString() : ''),
    receiverUsername: doc.receiverUsername || '',
    senderUsernames: Array.isArray(doc.senderUsernames) ? doc.senderUsernames : [],
    status: doc.status || 'active',
    permissions: doc.permissions || { canViewLiveGps: true, canViewHistory: true },
    assignedBy: doc.assignedBy || 'admin',
    notes: doc.notes || '',
    createdAt: doc.createdAt || new Date(),
    updatedAt: doc.updatedAt || new Date(),
  };
}

/**
 * Get all receiver mappings
 * GET /api/mappings
 */
exports.getAllMappings = async (req, res) => {
  try {
    if (mongoose.connection.readyState === 1) {
      const docs = await ReceiverMapping.find({}).sort({ updatedAt: -1 }).lean();
      return res.status(200).json({
        count: docs.length,
        mappings: docs.map(formatMapping),
      });
    }

    const fallbackList = Array.from(inMemoryMappings.values());
    return res.status(200).json({
      count: fallbackList.length,
      mappings: fallbackList,
    });
  } catch (error) {
    console.error('[MappingController] Error fetching mappings:', error);
    return res.status(500).json({ error: 'Failed to retrieve receiver mappings' });
  }
};

/**
 * Get mapping for a specific receiver
 * GET /api/mappings/receiver/:receiverUsername
 */
exports.getReceiverMapping = async (req, res) => {
  try {
    const rawUsername = req.params.receiverUsername || req.query.receiverUsername;
    if (!rawUsername || typeof rawUsername !== 'string') {
      return res.status(400).json({ error: 'Receiver username is required' });
    }

    const cleanReceiver = rawUsername.trim().toLowerCase();

    if (mongoose.connection.readyState === 1) {
      const doc = await ReceiverMapping.findOne({ receiverUsername: cleanReceiver }).lean();
      if (doc) {
        return res.status(200).json({
          isMapped: true,
          mapping: formatMapping(doc),
        });
      }
    } else if (inMemoryMappings.has(cleanReceiver)) {
      return res.status(200).json({
        isMapped: true,
        mapping: inMemoryMappings.get(cleanReceiver),
      });
    }

    return res.status(200).json({
      isMapped: false,
      mapping: {
        receiverUsername: cleanReceiver,
        senderUsernames: [],
        status: 'unmapped',
        permissions: { canViewLiveGps: false, canViewHistory: false },
      },
      message: `No senders have been mapped to receiver @${cleanReceiver} by the admin yet.`,
    });
  } catch (error) {
    console.error('[MappingController] Error fetching receiver mapping:', error);
    return res.status(500).json({ error: 'Failed to retrieve receiver mapping' });
  }
};

/**
 * Create or update a receiver-to-sender mapping
 * POST /api/mappings
 * Body: { receiverUsername, senderUsernames, status?, permissions?, notes? }
 */
exports.saveMapping = async (req, res) => {
  try {
    const { receiverUsername, senderUsernames, status, permissions, notes } = req.body;

    if (!receiverUsername || typeof receiverUsername !== 'string' || receiverUsername.trim().length === 0) {
      return res.status(400).json({ error: 'Receiver username is required' });
    }

    const cleanReceiver = receiverUsername.trim().toLowerCase();

    // Clean sender usernames array
    const rawSenders = Array.isArray(senderUsernames) ? senderUsernames : [];
    const cleanSenders = Array.from(new Set(
      rawSenders
        .map(s => (typeof s === 'string' ? s.trim() : ''))
        .filter(s => s.length > 0 && s !== 'User' && s !== 'Player_777')
    ));

    const mappingStatus = ['active', 'paused', 'revoked'].includes(status) ? status : 'active';
    const mappingPermissions = {
      canViewLiveGps: permissions?.canViewLiveGps !== false,
      canViewHistory: permissions?.canViewHistory !== false,
    };
    const cleanNotes = typeof notes === 'string' ? notes.trim() : '';
    const now = new Date();

    let savedData = {
      _id: new mongoose.Types.ObjectId().toString(),
      receiverUsername: cleanReceiver,
      senderUsernames: cleanSenders,
      status: mappingStatus,
      permissions: mappingPermissions,
      assignedBy: 'admin',
      notes: cleanNotes,
      createdAt: now,
      updatedAt: now,
    };

    if (mongoose.connection.readyState === 1) {
      const doc = await ReceiverMapping.findOneAndUpdate(
        { receiverUsername: cleanReceiver },
        {
          $set: {
            senderUsernames: cleanSenders,
            status: mappingStatus,
            permissions: mappingPermissions,
            assignedBy: 'admin',
            notes: cleanNotes,
            updatedAt: now,
          },
          $setOnInsert: {
            createdAt: now,
          }
        },
        {
          upsert: true,
          new: true,
          setDefaultsOnInsert: true,
        }
      );

      if (doc) {
        savedData = formatMapping(doc);
      }
    }

    // Keep in-memory cache synchronized
    inMemoryMappings.set(cleanReceiver, savedData);

    return res.status(200).json({
      success: true,
      message: `Receiver @${cleanReceiver} successfully mapped to [${cleanSenders.join(', ')}]`,
      mapping: savedData,
    });
  } catch (error) {
    console.error('[MappingController] Error saving mapping:', error);
    return res.status(500).json({ error: 'Failed to save receiver mapping' });
  }
};

/**
 * Delete a receiver mapping
 * DELETE /api/mappings/:receiverUsername
 */
exports.deleteMapping = async (req, res) => {
  try {
    const rawUsername = req.params.receiverUsername || req.query.receiverUsername;
    if (!rawUsername) {
      return res.status(400).json({ error: 'Receiver username is required to delete mapping' });
    }

    const cleanReceiver = rawUsername.trim().toLowerCase();

    if (mongoose.connection.readyState === 1) {
      if (mongoose.Types.ObjectId.isValid(cleanReceiver)) {
        await ReceiverMapping.findByIdAndDelete(cleanReceiver);
      } else {
        await ReceiverMapping.findOneAndDelete({ receiverUsername: cleanReceiver });
      }
    }

    inMemoryMappings.delete(cleanReceiver);

    return res.status(200).json({
      success: true,
      message: `Mapping for receiver @${cleanReceiver} has been removed.`,
    });
  } catch (error) {
    console.error('[MappingController] Error deleting mapping:', error);
    return res.status(500).json({ error: 'Failed to delete receiver mapping' });
  }
};
