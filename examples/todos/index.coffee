express = require 'express'
gzip = require 'connect-gzip'
fs = require 'fs'
shared = require './shared'

exports.app = app = express.createServer()
  .use(express.favicon())
  .use('/todos', gzip.staticGzip(__dirname))
Racer = require('racer').Racer
exports.racer = racer = new Racer
  redis:
    db: 2
  # The listen option accepts either a port number or a node HTTP server
  listen: app
exports.store = store = racer.store

# racer.js returns a browserify bundle of the racer client side code and the
# socket.io client side code as well as any additional browserify options
racer.js require: __dirname + '/shared', entry: __dirname + '/client.js', (js) ->
  fs.writeFileSync __dirname + '/script.js', js

app.get '/todos', (req, res) ->
  res.redirect 'racer'

app.get '/todos/:group', (req, res) ->
  group = req.params.group
  store.subscribe _group: "groups.#{group}.**", (err, model) ->
    initGroup model
    # Currently, refs must be explicitly declared per model; otherwise the ref
    # is not added the model's internal reference indices
    model.set '_group.todoList', model.arrayRef '_group.todos', '_group.todoIds'
    # model.bundle waits for any pending model operations to complete and then
    # returns the JSON data for initialization on the client
    model.bundle (bundle) ->
      listHtml = (shared.todoHtml todo for todo in model.get '_group.todoList').join('')
      res.send """
      <!DOCTYPE html>
      <title>Todos</title>
      <link rel=stylesheet href=style.css>
      <body>
      <div id=overlay></div>
      <!-- calling via timeout keeps the page from redirecting if an error is thrown -->
      <form id=head onsubmit="setTimeout(todos.addTodo, 0);return false">
        <h1>Todos</h1>
        <div id=add><div id=add-input><input id=new-todo></div><input id=add-button type=submit value=Add></div>
      </form>
      <div id=dragbox></div>
      <div id=content><ul id=todos>#{listHtml}</ul></div>
      <script>init=#{bundle}</script>
      <script src=https://ajax.googleapis.com/ajax/libs/jquery/1.6.2/jquery.min.js></script>
      <script src=https://ajax.googleapis.com/ajax/libs/jqueryui/1.8.15/jquery-ui.min.js></script>
      <script src=script.js></script>
      """

initGroup = (model) ->
  return if model.get '_group'
  model.set '_group.todos',
    0: {id: 0, completed: true, text: 'This one is done already'}
    1: {id: 1, completed: false, text: 'Example todo'}
    2: {id: 2, completed: false, text: 'Another example'}
  model.set '_group.todoIds', [1, 2, 0]
  model.set '_group.nextId', 3
