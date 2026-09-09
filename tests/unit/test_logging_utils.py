import logging

from steamostools.logging_utils import initialize_logger


def test_initialize_logger_sets_level_and_scope():
    logger = initialize_logger(log_level=logging.DEBUG, scope="test.scope.level")
    assert logger.name == "test.scope.level"
    assert logger.level == logging.DEBUG
    assert logger.propagate is False


def test_initialize_logger_writes_to_file(tmp_path):
    log_file = tmp_path / "logs" / "test.log"
    logger = initialize_logger(log_filename=str(log_file), scope="test.scope.file")
    logger.info("hello from test")
    for handler in logger.handlers:
        handler.flush()
    assert log_file.exists()
    assert "hello from test" in log_file.read_text()


def test_initialize_logger_is_idempotent_for_repeated_calls():
    """Calling with the same scope twice should not accumulate duplicate handlers."""
    initialize_logger(scope="test.scope.repeat")
    logger = initialize_logger(scope="test.scope.repeat")
    assert len(logger.handlers) == 1


def test_initialize_logger_suppresses_noisy_loggers_by_default():
    initialize_logger(scope="test.scope.noisy")
    assert logging.getLogger("urllib3").level == logging.WARNING


def test_initialize_logger_debug_more_leaves_noisy_loggers_alone():
    logging.getLogger("urllib3").setLevel(logging.NOTSET)
    initialize_logger(scope="test.scope.debug_more", debug_more=True)
    assert logging.getLogger("urllib3").level == logging.NOTSET
