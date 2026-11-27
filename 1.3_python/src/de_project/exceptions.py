class RateLimitError(Exception):
    """API rate limit vẫn bị giới hạn sau số lần retry cho phép."""


class APIRequestError(Exception):
    """Không thể gọi API sau số lần retry cho phép."""


class DataValidationError(Exception):
    """Cấu trúc JSON API không đúng định dạng mong đợi."""
