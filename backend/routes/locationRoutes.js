const express = require('express');
const router = express.Router();
const locationController = require('../controllers/locationController');

// POST /api/location - X uploads current location
router.post('/location', locationController.updateLocation);

// GET /api/location - Y fetches latest location for X
router.get('/location', locationController.getLocation);

// GET /api/locations - Get all shared locations from database
router.get('/locations', locationController.getAllLocations);

// GET /api/user-activity - Get user activity logs (username + location history)
router.get('/user-activity', locationController.getUserActivity);

module.exports = router;
