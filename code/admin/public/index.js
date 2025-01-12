<!DOCTYPE html>
<html xmlns:ng="http://angularjs.org" id='ng-app' ng-app="adminApp">

<head>

    <title>Fleet Manager</title>

    <script src="javascripts/bower_components/jquery/dist/jquery.min.js"></script>

    <script src="http://maps.googleapis.com/maps/api/js?libraries=weather,geometry,visualization,places&sensor=false&language=en&v=3.14"></script>
    <script src="javascripts/ContextMenu.js"></script>

    <script src="http://ajax.googleapis.com/ajax/libs/angularjs/1.2.18/angular.js"></script>

    <script src="http://ajax.googleapis.com/ajax/libs/angularjs/1.2.18/angular-sanitize.js"></script>

    <script src="http://ajax.googleapis.com/ajax/libs/angularjs/1.2.18/angular-animate.js"></script>


    <link rel="styleSheet" href="javascripts/bower_components/angular-ui-grid/ui-grid-unstable.min.css" />
    <script src="javascripts/bower_components/angular-ui-grid/ui-grid-unstable.js"></script>

    <!--<script src="//netdna.bootstrapcdn.com/twitter-bootstrap/2.3.2/js/bootstrap.min.js"></script>-->
    <!--<script src="//cdnjs.cloudflare.com/ajax/libs/lodash.js/2.4.1/lodash.min.js" type="text/javascript"></script>-->
    <script src="javascripts/bower_components/lodash/dist/lodash.min.js" type="text/javascript"></script>
    <!--<script src="//angular-ui.github.io/bootstrap/ui-bootstrap-tpls-0.11.0.js" type="text/javascript"></script>-->
    <script src="javascripts/bower_components/angular-bootstrap/ui-bootstrap-tpls.min.js" type="text/javascript"></script>
    <script src="javascripts/bower_components/angular-ui-select/dist/select.js"></script>
	    <link rel="stylesheet" href="javascripts/bower_components/angular-ui-select/dist/select.min.css">

    <script src="javascripts/bower_components/message-center/message-center.js"></script>
    <script src="javascripts/bower_components/angular-flash/dist/angular-flash.min.js"></script>
    <script src="javascripts/bower_components/angular-google-maps/dist/angular-google-maps.js"></script>

    <script src="javascripts/bower_components/angular-ui-tree/dist/angular-ui-tree.min.js"></script>
    <link rel="stylesheet" href="javascripts/bower_components/angular-ui-tree/dist/angular-ui-tree.min.css">

    <script src="javascripts/RouteController.js"></script>

    <link rel='stylesheet' href='/stylesheets/style.css' />
    <link rel='stylesheet' href='/stylesheets/map.css' />
    <link rel='stylesheet' href='/stylesheets/context_menu.css' />
    <!--<link href="//netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css" rel="stylesheet" type="text/css">-->
    <link href="javascripts/bower_components/bootstrap/dist/css/bootstrap.min.css" rel="stylesheet" type="text/css">


	

    <!--<link rel="stylesheet" href="http://cdnjs.cloudflare.com/ajax/libs/selectize.js/0.8.5/css/selectize.default.css">-->
    <link rel="stylesheet" href="javascripts/bower_components/selectize/dist/css/selectize.default.css">
	


</head>

<body ng-controller="RouteController">
OLD
    <div>
        <ny-fleet-choice ny-fleet="fleet" ny-fleets="fleets" ny-changed="fleetChosen"></ny-fleet-choice># Routes: {{fleetDetail.routes.length}} # Stops: {{fleetDetail.stops.length}} # Unnamed stops: {{fleetDetail.stops.length}}
        Logged in as
        <%= user.username %>,
            <% if(user.role==1 ) { %>Fleet Administrator
                <% } %> <a href='/logout'>Logout</a>
                    <!-- <flash:messages class="slide-down" ng:show="messages"></flash:messages> -->
                    <mc-messages></mc-messages>
                    <!-- Subscribe to all flash messages. TODO : Do what is done at http://embed.plnkr.co/zXGEKw/preview -->
                    <div flash-alert active-class="in alert" class="alert fade" align="right">
                        <span class="alert-message">{{flash.message}}</span>
                    </div>
                    <tabset vertical="false" justified="false">
                        <tab heading="Routes">
                            <table border="1" width=100% height=100%>
                                <tr>
                                    <td width=15% valign="top">
									<b>Routes</b>
									<div ui-grid="routeListOptions" ui-grid-selection ui-grid-auto-resize></div>
                                    </td>
                                    <td width=70% valign="top">
                                        <div id="route">

                                            Route options:
                                            <button type="button" ng-click="newRoute()" class="btn btn-primary btn-xs">New</button>
                                            <button type="submit" ng-click="saveRoute()" class="btn btn-primary btn-xs" ng-disabled="!routeDetail.isDirty">Save</button>
                                            <button type="submit" ng-click="saveRoute()" class="btn btn-danger btn-xs" ng-disabled="!routeDetail.isDirty">Cancel</button>
                                            <button type="submit" ng-click="extendRoute()" class="btn btn-primary btn-xs" ng-disabled="routeDetail.routeId <= 0 ">Extend</button>
                                            <button type="submit" ng-click="closeRoute()" class="btn btn-primary btn-xs" ng-disabled="routeDetail.routeId <= 0 ">Close</button>
                                        </div>
                                        <tabset vertical="false" justified="false">
                                            <tab heading="Map">

                                                <ui-gmap-google-map class="span7" events="mapEvents" zoom="fleetDetail.zoom" center="fleetDetail.center" draggable="true" bounds="fleetDetail.bounds" pan="true" control="map.control">
												
												<ny-ui-gmap-control gmap="gmap" bounds="fleetDetail.bounds"></ny-ui-gmap-control>

                                                    <ui-gmap-window show="map.infoWindow.show" coords="stopDetail" isIconVisibleOnClick="false" ng-cloak>
                                                        <div>


                                                            <form name="stop_form" ng-controller="StopController" ng-submit="saveStop()" novalidate>
                                                                <p>Adding stop at {{ stopDetail.latitude | number:4 }}, {{ stopDetail.longitude | number:4 }}</p>
                                                                <br/>
                                                                <input type="text" name="stopName" placeholder="Stop Name" ng-model="stopDetail.name" ng-required="true" />
                                                                <br/>
                                                                <textarea ng-model="stopDetail.address" placeholder="Stop Address"></textarea>
                                                                <br/>
                                                                <button type="submit" ng-disabled="stop_form.$invalid">Save</button>

                                                            </form>

                                                        </div>
                                                    </ui-gmap-window>

                                                    <ui-gmap-markers models="fleetDetail.stops" coords="'self'" icon="'icon'" click="'onClicked'" options="'options'" events="stopEvents" labelContent="'name'">
                                                    </ui-gmap-markers>

                                                </ui-gmap-google-map>

                                            </tab>
                                            <!--Map tab ends -->
                                            <tab heading="Schedule-CM">
                                                <div ui-grid="scheduleOptions" ui-grid-edit ui-grid-row-edit ui-grid-cellNav ui-grid-auto-resize></div>
                                            </tab>
                                            <tab heading="Fares-CM"></tab>
                                            <tab heading="Object">
                                                <pre class="code">{{ fleetDetail | json }}</pre>
                                            </tab>
                                        </tabset>
                                    </td>

                                    <td width=15% valign="top">

                                        <tabset>
                                            <tab heading="Onward-YG">

                                                <div ui-tree="stageTreeOptions">
                                                    <!-- for existing stages -->
                                                    <ol ui-tree-nodes ng-model="routeDetail.stages" data-type="group">
                                                        <li ng-repeat="stage in routeDetail.stages" ui-tree-node>
                                                            <div class="group-title angular-ui-tree-handle" ng-show="!stage.editing">
                                                                <a href="" class="btn btn-danger btn-xs pull-right" data-nodrag ng-click="removeGroup(stage)" ng-show="stage.stops.length>0"><i class="glyphicon glyphicon-remove"></i></a>
                                                                <a href="" class="btn btn-primary btn-xs pull-right" data-nodrag ng-click="stage.editing=true"><i class="glyphicon glyphicon-pencil"></i></a>
                                                                <div>{{stage.title}}</div>
                                                            </div>
                                                            <div class="group-title angular-ui-tree-handle" data-nodrag ng-show="stage.editing">
                                                                <form class="form-inline" role="form">
                                                                    <div class="form-group">
                                                                        <label class="sr-only" for="title">Stage name</label>
                                                                        <input type="text" class="form-control" placeholder="Stage name" ng-model="stage.title">
                                                                    </div>
                                                                    <button type="submit" class="btn btn-default" ng-click="stage.editing=false">Save</button>
                                                                    <button type="submit" class="btn btn-default" ng-click="stage.editing=false">Cancel</button>
                                                                </form>
                                                            </div>
                                                            <ol ui-tree-nodes ng-model="stage.stops" data-type="category">
                                                                <li ng-repeat="stop in stage.stops" ui-tree-node>
                                                                    <div class="category-title angular-ui-tree-handle">
                                                                        <!--<a href="" class="btn btn-danger btn-xs pull-right" data-nodrag ng-click="removeCategory(stage, stop)"><i class="glyphicon glyphicon-remove"></i></a>-->
                                                                        <div>
                                                                            {{stop.name}}
                                                                        </div>
                                                                    </div>
                                                                </li>
                                                            </ol>

                                                        </li>
                                                    </ol>
                                                    <ol class="angular-ui-tree-nodes">
                                                        <li class="angular-ui-tree-node">
                                                            <div class="group-title angular-ui-tree-handle">
                                                                <form class="form-inline" role="form">
                                                                    <div class="form-group">
                                                                        <label class="sr-only" for="title">Stage name</label>
                                                                        <input type="text" class="form-control" id="stageName" ng-model="newStage.title" placeholder="Stage name">
                                                                    </div>
                                                                    <button type="submit" class="btn btn-default" ng-click="addNewStage()">Add Stage</button>
                                                                </form>
                                                            </div>
                                                        </li>
                                                    </ol>
                                                </div>

                                            </tab>
                                            <tab heading="Return">RR</tab>
                                        </tabset>
                                    </td>
                                </tr>
                            </table>

                        </tab>
                        <tab heading="Calendars-AN">
                            <button ng-click="addCalendar()" class="btn btn-default">Add</button>
                            <button ng-click="saveCalendars()" class="btn btn-default">Save</button>
                            <div ui-grid="calendarOptions" ui-grid-edit ui-grid-row-edit ui-grid-cellNav ui-grid-auto-resize class="myGrid"></div>
                        </tab>
                    </tabset>
    </div>
</body>

</html>
