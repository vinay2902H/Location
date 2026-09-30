const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

// POST /api/auth/register or /api/register
router.post('/register', authController.register);

// POST /api/auth/login or /api/login
router.post('/login', authController.login);

// POST /api/auth/username-login (receiver/sender quick username-only authentication)
router.post('/username-login', authController.usernameLogin);

// GET /api/auth/users
router.get('/users', authController.getUsers);

module.exports = router;
