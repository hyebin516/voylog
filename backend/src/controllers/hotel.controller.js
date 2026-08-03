const hotelService = require('../services/hotel.service');
const { success } = require('../utils/response');

function toHotelResponse(hotel) {
  return {
    hotelId: hotel.hotel_id,
    name: hotel.name,
    address: hotel.address,
    latitude: Number(hotel.latitude),
    longitude: Number(hotel.longitude),
    createdAt: hotel.created_at,
    updatedAt: hotel.updated_at,
  };
}

async function create(req, res, next) {
  try {
    const hotel = await hotelService.createHotel(req.user.userId, req.body);
    return success(res, toHotelResponse(hotel), 201);
  } catch (err) {
    return next(err);
  }
}

async function list(req, res, next) {
  try {
    const hotels = await hotelService.listHotels(req.user.userId);
    return success(res, { hotels: hotels.map(toHotelResponse) });
  } catch (err) {
    return next(err);
  }
}

async function update(req, res, next) {
  try {
    const hotel = await hotelService.updateHotel(req.user.userId, req.params.id, req.body);
    return success(res, toHotelResponse(hotel));
  } catch (err) {
    return next(err);
  }
}

async function remove(req, res, next) {
  try {
    await hotelService.deleteHotel(req.user.userId, req.params.id);
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
}

module.exports = { create, list, update, remove };
