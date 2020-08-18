( function _Basic_s_()
{

'use strict';

/**
 * Collection of routines to execute system commands, run shell, batches, launch external processes from JavaScript application. Module Process leverages not only outputting data from an application but also inputting, makes application arguments parsing and accounting easier. Use the module to get uniform experience from interaction with an external processes on different platforms and operating systems.
  @module Tools/base/ProcessBasic
*/

/**
 * Collection of routines to execute system commands, run shell, batches, launch external processes from JavaScript application.
  @namespace Tools.process
  @extends Tools
  @module Tools/base/ProcessBasic
*/

if( typeof module !== 'undefined' )
{

  let _ = require( '../../../wtools/Tools.s' );

  _.include( 'wPathBasic' );
  _.include( 'wGdf' );
  _.include( 'wConsequence' );

  require( './l3/Execution.s' );
  require( './l3/Io.s' );

}

let System, ChildProcess, StripAnsi, WindowsKill, WindowsProcessTree;
let _global = _global_;
let _ = _global_.wTools;
let Self = _.process = _.process || Object.create( null );

_.assert( !!_realGlobal_ );

// --
// temp
// --

let _tempFiles = [];

function tempOpen_pre( routine, args )
{
  let o;

  if( _.strIs( args[ 0 ] ) || _.bufferRawIs( args[ 0 ] ) )
  o = { sourceCode : args[ 0 ] };
  else
  o = args[ 0 ];

  o = _.routineOptions( routine, o );

  _.assert( arguments.length === 2 );
  _.assert( args.length === 1, 'Expects single argument' );

  return o;
}

function tempOpen_body( o )
{
  _.assertRoutineOptions( tempOpen, arguments );
  _.assert( arguments.length === 1, 'Expects single argument' );
  _.assert( _.strIs( o.sourceCode ) || _.bufferRawIs( o.sourceCode ), 'Expects string or buffer raw {-o.sourceCode-}, but got', _.strType( o.sourceCode ) );

  let tempDirPath = _.path.tempOpen( _.path.current() );
  let filePath = _.path.join( tempDirPath, _.idWithDateAndTime() + '.ss' );
  _tempFiles.push( filePath );
  _.fileProvider.fileWrite( filePath, o.sourceCode );
  return filePath;
}

var defaults = tempOpen_body.defaults = Object.create( null );
defaults.sourceCode = null;

let tempOpen = _.routineFromPreAndBody( tempOpen_pre, tempOpen_body );

//

function tempClose_pre( routine, args )
{
  let o;

  if( _.strIs( args[ 0 ] ) )
  o = { filePath : args[ 0 ] };
  else
  o = args[ 0 ];

  if( !o )
  o = Object.create( null );

  o = _.routineOptions( routine, o );

  _.assert( arguments.length === 2 );
  _.assert( args.length <= 1, 'Expects single argument or none' );

  return o;
}

function tempClose_body( o )
{
  _.assertRoutineOptions( tempClose, arguments );
  _.assert( arguments.length === 1, 'Expects single argument' );
  _.assert( _.strIs( o.filePath ) || o.filePath === null, 'Expects string or null {-o.filePath-}, but got', _.strType( o.filePath ) );

  if( !o.filePath )
  {
    if( !_tempFiles.length )
    return;

    _.fileProvider.filesDelete( _tempFiles );
    _tempFiles.splice( 0 );
  }
  else
  {
    let i = _.longLeftIndex( _tempFiles, o.filePath );
    _.assert( i !== -1, 'Requested {-o.filePath-}', o.filePath, 'is not a path of temp application.' )
    _.fileProvider.fileDelete( o.filePath );
    _tempFiles.splice( i, 1 );
  }
}

var defaults = tempClose_body.defaults = Object.create( null );
defaults.filePath = null;

let tempClose = _.routineFromPreAndBody( tempClose_pre, tempClose_body );

// //
//
// function insideTestContainer()
// {
//   return 'CI' in process.env && 'GITHUB_ACTIONS' in process.env;
// }

/**
 * Returns path for main module (module that running directly by node).
 * @returns {String}
 * @function realMainFile
 * @namespace Tools.process
 * @module Tools/base/ProcessBasic
 */

let _pathRealMainFile;
function realMainFile()
{
  if( _pathRealMainFile )
  return _pathRealMainFile;
  _pathRealMainFile = _.path.normalize( require.main.filename );
  return _pathRealMainFile;
}

/**
 * Returns path dir name for main module (module that running directly by node).
 * @returns {String}
 * @function realMainDir
 * @namespace Tools.process
 * @module Tools/base/ProcessBasic
 */

let _pathRealMainDir;
function realMainDir()
{
  if( _pathRealMainDir )
  return _pathRealMainDir;

  if( require.main )
  _pathRealMainDir = _.path.normalize( _.path.dir( require.main.filename ) );
  else
  return this.effectiveMainFile();

  return _pathRealMainDir;
}

/**
 * Returns absolute path for file running directly by node
 * @returns {String}
 * @throws {Error} If passed any argument.
 * @function effectiveMainFile
 * @namespace Tools.process
 * @module Tools/base/ProcessBasic
 */

let effectiveMainFile = ( function effectiveMainFile()
{
  let result = '';

  return function effectiveMainFile() /* qqq2 : move to process, review */
  {
    _.assert( arguments.length === 0, 'Expects no arguments' );

    if( result )
    return result;

    if( process.argv[ 0 ] || process.argv[ 1 ] )
    {
      result = _.path.join( this._currentAtBegin, process.argv[ 1 ] || process.argv[ 0 ] );
      result = _.path.resolve( result );
    }

    if( !_.fileProvider.fileExists( result ) )
    {
      //xxx : review
      debugger;
      console.error( 'process.argv :', process.argv.join( ', ' ) );
      console.error( 'currentAtBegin :', this._currentAtBegin );
      console.error( 'effectiveMainFile.raw :', this.join( this._currentAtBegin, process.argv[ 1 ] || process.argv[ 0 ] ) );
      console.error( 'effectiveMainFile :', result );
      result = this.realMainFile();
    }

    return result;
  }

})();

// --
// eventer
// --

let _on = _.process.on;
function on()
{
  let o2 = _on.apply( this, arguments );

  if( o2.callbackMap.available )
  _.process._eventAvailableHandle();

  return o2;
}

on.defaults =
{
  callbackMap : null,
}

//

function eventGive()
{
  return _.event.eventGive( _.process._ehandler, ... arguments );
}

eventGive.defaults =
{
  ... _.event.eventGive.defaults,
}

//

function _eventAvailableHandle()
{
  if( !_.process._ehandler.events.available.length )
  return;

  let callbacks = _.process._ehandler.events.available.slice();
  callbacks.forEach( ( callback ) =>
  {
    try
    {
      _.arrayRemoveOnceStrictly( _.process._ehandler.events.available, callback );
      callback.call( _.process );
    }
    catch( err )
    {
      throw _.err( `Error in handler::${callback.name} of an event::available of module::Process\n`, err );
    }
  });

}

// --
// meta
// --

function _Setup1()
{
  this._currentAtBegin = _.path.current();

  _.process._eventAvailableHandle();
  _.process._exitHandlerRepair();
  _.process._eventExitSetup();

}

// --
// declare
// --

let Events =
{
  available : [],
  exit : [],
}

let Extension =
{

  // temp

  tempOpen,
  tempClose,

  // // checker
  //
  // insideTestContainer,

  realMainFile,
  realMainDir,
  effectiveMainFile,

  // eventer

  on,
  eventGive,
  _eventAvailableHandle,

  // meta

  _Setup1,

  // fields

  _tempFiles,
  _registeredExitHandler : null,
  _currentAtBegin : null

}

_.mapExtend( Self, Extension );
_.mapSupplement( Self._ehandler.events, Events );
_.assert( _.routineIs( _.process.start ) );
_.process._Setup1();

// --
// export
// --

if( typeof module !== 'undefined' )
module[ 'exports' ] = _;

})();