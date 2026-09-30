const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

// POST /api/auth/register or /api/register
router.post('/register', authController.register);

// POST /api/auth/login or /api/login
router.post('/login', authController.login);

// GET /api/auth/users
router.get('/users', authController.getUsers);

module.exports = router;
