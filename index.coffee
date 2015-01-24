PersonController = require 'members-area/app/controllers/person'
bcrypt = require 'members-area/node_modules/bcrypt'

module.exports =
  initialize: (done) ->
    @app.addRoute 'all' , '/pincodes' , 'members-area-pin-codes#pin-codes#list'
    @app.addRoute 'all', '/settings/pin-codes', 'members-area-pin-codes#pin-codes#settings'
    @app.addRoute 'post' , '/pincodes/open' , 'members-area-pin-codes#pin-codes#open'
    @hook 'render-person-view' , @modifyUserPage.bind(this)
    @hook 'navigation_items', @modifyNavigationItems.bind(this)
    @hook 'models:initialize', ({models}) =>
      models.Pinentry.hasOne 'user', models.User, reverse: 'pinentry'
    PersonController.before @processPin, only: ['view']
    done()

  modifyUserPage: (options, done) ->
    {controller, $} = options
    return done() unless controller.loggedInUser.can('admin') or controller.user.id is controller.loggedInUser.id

    #Get meta for currently selected user (not request user)
    hasCode = controller.user.meta.pincode?

    message =
      if hasCode
        "<p class='text-success'>You already have a PIN code set</p>"
      else
        "<p class='text-warning'>You've not got a PIN code set, please set one up below</p>"

    htmlToAdd = """
      <h3>Manage PIN Code</h3>
      #{message}
      <form method='POST' class='form-horizontal'>
        <h4>Update PIN code</h4>
        <input type='hidden' name='replacePin' value='pin'>
        <div class="control-group">
          <label for="pin" class="control-label">8 digit PIN Code</label>
          <div class="controls">
            <input id="pin" name="pin" placeholder="00000000"><br />
            #{if controller.pinError then "<p class='text-error'>#{controller.pinError}</p>" else ""}
          </div>
        </div>
        <div class="control-group">
          <div class="controls">
            <button type="Submit" class="btn-success">Update</button>
          </div>
        </div>
      </form>
      """

    $(".main").append htmlToAdd

    done()

  processPin: (done) ->
    return done() unless @user.id is @loggedInUser.id
    if @req.method is 'POST' and @req.body.replacePin
      newPin = String(@req.body.pin)
      if newPin.match /^[0-9]{8}$/

        lpad = (id) ->
          r = String(id)
          while r.length < 4
            r = "0#{r}"
          return r

        fullPin = lpad(@user.id) + newPin

        bcrypt.hash fullPin, 10, (err, hash) =>
          return done err if err
          @user.setMeta
            pincode: fullPin
            hashedPincode: hash
          @user.save done
      else
        @pinError = "Invalid pin code"
        done()
    else
      done()

  modifyNavigationItems: ({addItem}) ->
    addItem 'settings',
      title: 'PIN codes'
      id: 'members-area-pin-codes-settings'
      href: '/settings/pin-codes'
      priority: 20
      permissions: ['admin']
    return
