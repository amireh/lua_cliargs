local cli = require('../src.cliargs')

cli:set_name('test-command')
cli:argument('ROOT', '...')

return cli:parse()