# [risk-reward.herokuapp.com](https://risk-reward.herokuapp.com/)

## Setup

#### Create app

```
$ heroku create
```

#### Set config

Get your API key and oauth secret from https://trello.com/1/appKey/generate

```
$ heroku config:add TRELLO_API_KEY=... TRELLO_OAUTH_SECRET=...
```

#### Deploy

```
$ git push heroku master
```
