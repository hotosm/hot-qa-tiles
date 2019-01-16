## development

`git clone git@github.com:hotosm/hot-qa-tiles.git` </br>
`cd hot-qa-tiles` </br>
`npm install`

## setup stack

`cd hot-qa-tiles` </br>
`cfn-config create staging ./cloudformation/hot-qa-tiles.template.js -t "hot-qa-tiles" -c "hot-qa-tiles"`

## delete stack

`cd hot-qa-tiles` </br>
`cfn-config delete staging ./cloudformation/hot-qa-tiles.template.js -t "hot-qa-tiles" -c "hot-qa-tiles"`
