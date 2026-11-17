const asyncHandler = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

const slugify = (text = '') =>
  text.toString().toLowerCase().trim()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-');

const round2 = (n) => Math.round(n * 100) / 100;

module.exports = { asyncHandler, ApiError, slugify, round2 };
