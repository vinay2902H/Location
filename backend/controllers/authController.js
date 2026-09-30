const mongoose = require('mongoose');
const User = require('../models/User');

// In-memory user store for resilient fallback when MongoDB is offline
const inMemoryUsers = new Map();

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Register a new user
 * POST /api/auth/register
 */
exports.register = async (req, res) => {
  try {
    const { email, username, password } = req.body;

    // 1. Validation
    if (!email || typeof email !== 'string' || !EMAIL_REGEX.test(email.trim())) {
      return res.status(400).json({ error: 'Please provide a valid email address' });
    }

    const cleanEmail = email.trim().toLowerCase();
    const cleanUsername = (username && typeof username === 'string') ? username.trim() : cleanEmail.split('@')[0];
    const cleanPassword = (password && typeof password === 'string') ? password : '';

    if (cleanUsername.length < 3) {
      return res.status(400).json({ error: 'Username must be at least 3 characters long' });
    }

    if (cleanPassword.length < 4) {
      return res.status(400).json({ error: 'Password must be at least 4 characters long' });
    }

    const isDbConnected = mongoose.connection.readyState === 1;

    // 2. Check for duplicate user
    if (isDbConnected) {
      try {
        const existing = await User.findOne({
          $or: [
            { email: cleanEmail },
            { username: cleanUsername }
          ]
        });

        if (existing) {
          if (existing.email === cleanEmail) {
            return res.status(409).json({ error: 'An account with this email already exists' });
          }
          return res.status(409).json({ error: 'An account with this username already exists' });
        }
      } catch (dbErr) {
        console.warn('[AuthController] DB find error, falling back to memory check:', dbErr.message);
      }
    }

    // Check in-memory map
    if (inMemoryUsers.has(cleanEmail)) {
      return res.status(409).json({ error: 'An account with this email already exists' });
    }

    // 3. Create user
    let savedUser = {
      _id: `mem_${Date.now()}`,
      email: cleanEmail,
      username: cleanUsername,
      password: cleanPassword,
      lastLogin: new Date(),
      createdAt: new Date(),
    };

    if (isDbConnected) {
      try {
        const doc = await User.create({
          email: cleanEmail,
          username: cleanUsername,
          password: cleanPassword,
          lastLogin: new Date(),
        });
        savedUser = {
          _id: doc._id.toString(),
          email: doc.email,
          username: doc.username,
          password: doc.password,
          lastLogin: doc.lastLogin,
          createdAt: doc.createdAt,
        };
      } catch (saveErr) {
        console.warn('[AuthController] MongoDB create failed, storing in memory:', saveErr.message);
      }
    }

    // Always update in-memory cache
    inMemoryUsers.set(cleanEmail, savedUser);
    inMemoryUsers.set(cleanUsername.toLowerCase(), savedUser);

    console.log(`[AuthController] User registered successfully: ${cleanEmail} (${cleanUsername})`);

    return res.status(201).json({
      success: true,
      message: 'Account created successfully',
      user: {
        id: savedUser._id,
        email: savedUser.email,
        username: savedUser.username,
        password: savedUser.password,
      }
    });

  } catch (error) {
    console.error('[AuthController] Registration error:', error);
    return res.status(500).json({ error: 'Internal server error during registration' });
  }
};

/**
 * Login user with email & password
 * POST /api/auth/login
 */
exports.login = async (req, res) => {
  try {
    const { email, username, password } = req.body;
    const identifier = (email || username || '').trim();
    const cleanPassword = (password && typeof password === 'string') ? password : '';

    if (!identifier || !cleanPassword) {
      return res.status(400).json({ error: 'Please provide both email/username and password' });
    }

    const lowerId = identifier.toLowerCase();
    const isDbConnected = mongoose.connection.readyState === 1;
    let foundUser = null;

    if (isDbConnected) {
      try {
        foundUser = await User.findOne({
          $or: [
            { email: lowerId },
            { username: identifier }
          ]
        });
      } catch (dbErr) {
        console.warn('[AuthController] DB login query failed, checking memory:', dbErr.message);
      }
    }

    // Fallback to in-memory store
    if (!foundUser) {
      foundUser = inMemoryUsers.get(lowerId);
    }

    if (!foundUser) {
      return res.status(401).json({ error: `No account found for "${identifier}". Please create an account.` });
    }

    // Validate password
    if (foundUser.password !== cleanPassword) {
      return res.status(401).json({ error: 'Incorrect password. Please try again.' });
    }

    // Update lastLogin
    const now = new Date();
    if (isDbConnected && foundUser._id && typeof foundUser.save === 'function') {
      try {
        foundUser.lastLogin = now;
        await foundUser.save();
      } catch (_) {}
    } else if (foundUser) {
      foundUser.lastLogin = now;
    }

    console.log(`[AuthController] User logged in: ${foundUser.email} (${foundUser.username})`);

    return res.status(200).json({
      success: true,
      message: 'Login successful',
      user: {
        id: foundUser._id ? foundUser._id.toString() : `mem_${Date.now()}`,
        email: foundUser.email,
        username: foundUser.username,
        password: foundUser.password,
      }
    });

  } catch (error) {
    console.error('[AuthController] Login error:', error);
    return res.status(500).json({ error: 'Internal server error during login' });
  }
};

/**
 * Get user list (summary)
 * GET /api/auth/users
 */
exports.getUsers = async (req, res) => {
  try {
    const isDbConnected = mongoose.connection.readyState === 1;
    let users = [];

    if (isDbConnected) {
      users = await User.find({})
        .select('email username password role lastLogin createdAt lastLocation')
        .sort({ createdAt: -1 })
        .limit(50)
        .lean();
    } else {
      // Memory users deduplicated
      const unique = new Set();
      for (const u of inMemoryUsers.values()) {
        if (!unique.has(u.email)) {
          unique.add(u.email);
          users.push(u);
        }
      }
    }

    return res.status(200).json({
      count: users.length,
      users: users.map(u => ({
        id: u._id,
        email: u.email,
        username: u.username,
        role: u.role || 'receiver',
        password: u.password,
        lastLogin: u.lastLogin,
        lastLocation: u.lastLocation,
        createdAt: u.createdAt,
      })),
    });
  } catch (error) {
    console.error('[AuthController] Error fetching users:', error);
    return res.status(500).json({ error: 'Failed to retrieve users' });
  }
};

/**
 * Username-only Login or Create for Receiver/Sender Connection
 * POST /api/auth/username-login
 * Body: { username: string, role?: 'receiver' | 'sender' }
 */
exports.usernameLogin = async (req, res) => {
  try {
    const { username, role } = req.body;
    if (!username || typeof username !== 'string' || username.trim().length < 2) {
      return res.status(400).json({ error: 'Please enter a username with at least 2 characters' });
    }

    const cleanUsername = username.trim();
    const userRole = role === 'sender' ? 'sender' : 'receiver';
    const isDbConnected = mongoose.connection.readyState === 1;

    let user = null;
    let isNewUser = false;

    if (isDbConnected) {
      // Find existing user by case-insensitive username
      user = await User.findOne({
        username: { $regex: new RegExp(`^${cleanUsername.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') }
      });

      if (!user) {
        // Create new user account with this username
        isNewUser = true;
        user = await User.create({
          username: cleanUsername,
          email: `${cleanUsername.toLowerCase().replace(/[^a-z0-9]/g, '')}@winzo.app`,
          password: 'nopassword',
          role: userRole,
          lastLogin: new Date()
        });
      } else {
        // Existing user logged in
        user.lastLogin = new Date();
        if (!user.role) {
          user.role = userRole;
        }
        await user.save().catch(() => {});
      }
    } else {
      // Memory fallback
      for (const u of inMemoryUsers.values()) {
        if (u.username.toLowerCase() === cleanUsername.toLowerCase()) {
          user = u;
          break;
        }
      }
      if (!user) {
        isNewUser = true;
        user = {
          _id: new mongoose.Types.ObjectId().toString(),
          username: cleanUsername,
          email: `${cleanUsername.toLowerCase().replace(/[^a-z0-9]/g, '')}@winzo.app`,
          password: 'nopassword',
          role: userRole,
          createdAt: new Date(),
          lastLogin: new Date()
        };
        inMemoryUsers.set(user.email, user);
        inMemoryUsers.set(user.username.toLowerCase(), user);
      } else {
        user.lastLogin = new Date();
        if (!user.role) user.role = userRole;
      }
    }

    console.log(`[AuthController] Username login/create: ${user.username} (role: ${user.role}, isNew: ${isNewUser})`);

    return res.status(200).json({
      message: isNewUser ? 'New user created successfully' : 'Logged in successfully',
      isNewUser,
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
        role: user.role,
        lastLogin: user.lastLogin
      }
    });
  } catch (error) {
    console.error('[AuthController] Username login error:', error);
    return res.status(500).json({ error: 'Failed to process username login' });
  }
};
