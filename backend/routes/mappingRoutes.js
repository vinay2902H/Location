const express = require('express');
const router = express.Router();
const mappingController = require('../controllers/mappingController');

// GET /api/mappings - List all receiver-to-sender mappings
router.get('/mappings', mappingController.getAllMappings);

// GET /api/mappings/receiver/:receiverUsername - Get mapping for specific receiver
router.get('/mappings/receiver/:receiverUsername', mappingController.getReceiverMapping);

// POST /api/mappings - Create or update a receiver mapping
router.post('/mappings', mappingController.saveMapping);

// DELETE /api/mappings/:receiverUsername - Delete a receiver mapping
router.delete('/mappings/:receiverUsername', mappingController.deleteMapping);

module.exports = router;
