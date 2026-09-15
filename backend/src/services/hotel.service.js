const hotelRepository = require('../repositories/hotel.repository');
const AppError = require('../utils/AppError');
const { callAiWorker } = require('./aiWorkerClient');

async function getOwnedHotel(userId, hotelId) {
  const hotel = await hotelRepository.findById(hotelId);
  if (!hotel || hotel.user_id !== userId) {
    throw new AppError(404, 'HOTEL_NOT_FOUND', 'Hotel not found');
  }
  return hotel;
}

async function createHotel(userId, hotel) {
  return hotelRepository.create(userId, hotel);
}

async function listHotels(userId) {
  return hotelRepository.findAllByUser(userId);
}

async function updateHotel(userId, hotelId, hotel) {
  await getOwnedHotel(userId, hotelId);
  return hotelRepository.update(hotelId, hotel);
}

async function deleteHotel(userId, hotelId) {
  await getOwnedHotel(userId, hotelId);
  await hotelRepository.softDelete(hotelId);
}

async function searchHotels(query) {
  const result = await callAiWorker('/geocode/search', { query }, 10000);
  return result.candidates || [];
}

async function reverseGeocode(latitude, longitude) {
  const result = await callAiWorker('/geocode/reverse', { latitude, longitude }, 10000);
  return result.address || null;
}

module.exports = {
  createHotel,
  listHotels,
  updateHotel,
  deleteHotel,
  getOwnedHotel,
  searchHotels,
  reverseGeocode,
};
