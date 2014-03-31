/*jshint camelcase: false*/
// Generated on 2013-10-25 using generator-chrome-extension 0.2.5
'use strict';
var mountFolder = function (connect, dir) {
  return connect.static(require('path').resolve(dir));
};

// # Globbing
// for performance reasons we're only matching one level down:
// 'test/spec/{,*/}*.js'
// use this if you want to recursively match all subfolders:
// 'test/spec/**/*.js'

module.exports = function (grunt) {
  // show elapsed time at the end
  require('time-grunt')(grunt);
  // load all grunt tasks
  require('load-grunt-tasks')(grunt);

  // configurable paths
  var yeomanConfig = {
    app: 'app',
    dist: 'dist',
    package: 'package',
    properties: 'properties',
    temp: 'temp'
  };

  grunt.initConfig({
    yeoman: yeomanConfig,
    watch: {
      options: {
        spawn: false
      },
      coffee: {
        files: ['<%= yeoman.app %>/scripts/{,*/}*.coffee'],
        tasks: ['coffee:dist']
      },
      all: {
        files: ['<%= yeoman.app %>/{,*/}*.*'],
        tasks: ['build']
      }
    },
    clean: {
      dist: {
        files: [
          {
            dot: true,
            src: [
              '<%= yeoman.dist %>/*',
              '!<%= yeoman.dist %>/.git*'
            ]
          }
        ]
      },
      package: {
        files: [
          {
            dot: true,
            src: [
              '<%= yeoman.package %>/*',
              '!<%= yeoman.package %>/.git*'
            ]
          }
        ]
      }
    },
    coffee: {
      base: {
        options: {
          bare: true
        },
        files: [
          {
            expand: true,
            cwd: '<%= yeoman.app %>/scripts',
            src: '{,*/}*.coffee',
            dest: '<%= yeoman.dist %>/scripts',
            ext: '.js'
          },
          {
            expand: true,
            cwd: '<%= yeoman.app %>/lib',
            src: '{,*/}*.coffee',
            dest: '<%= yeoman.temp %>/lib',
            ext: '.js'
          },
          {
            '<%= yeoman.dist %>/scripts/properties.js': '<%= yeoman.properties %>/dev.coffee'
          }
        ]
      },
      prod: {
        options: {
          bare: true
        },
        files: {
          '<%= yeoman.dist %>/scripts/properties.js': '<%= yeoman.properties %>/prod.coffee'
        }
      }
    },
    // Put files not handled in other tasks here
    copy: {
      dist: {
        files: [
          {
            expand: true,
            dot: true,
            cwd: '<%= yeoman.app %>',
            dest: '<%= yeoman.dist %>',
            src: [
              '*.{ico,png,txt}',
              'images/{,*/}*.{webp,gif,jpg,jpeg,png,svg}',
              'manifest.json',
              'scripts/{,*}/*.js',
              'styles/{,*/}*.css',
              '{,*/}*.html',
              'data/{,*/}*',
              'bower_components/{,*}*'
            ]
          },
          {
            expand: true,
            dot: true,
            cwd: '<%= yeoman.app %>',
            dest: '<%= yeoman.temp %>',
            src: [
              'lib/{,*}/*.js'
            ]
          },
          {
            expand: true,
            dot: true,
            cwd: 'node_modules/malory',
            dest: '<%= yeoman.dist %>/scripts',
            src: [
              'malory.js'
            ]
          }
        ]
      }
    },
    hogan: {
      dist: {
        options: {
          prettify: true,
          defaultName: function(filename) {
            return filename.split('/').pop().split('.html').shift();
          }
        },
        files: {
          "<%= yeoman.dist %>/scripts/templates.js": ["<%= yeoman.app %>/templates/*.html"]
        }
      }
    },
    concurrent: {
      dist: [
        'coffee:base',
        'hogan:dist'
      ]
    },
    browserify: {
      dist: {
        files: {
          '<%= yeoman.dist %>/scripts/vendor-background.js': ['<%= yeoman.app %>/vendor/vendor-background.js'],
          '<%= yeoman.dist %>/scripts/vendor-content.js': ['<%= yeoman.app %>/vendor/vendor-content.js']
        },
        debug: true
      }
    },
    crx: {
      dist: {
        "src": "<%= yeoman.dist %>",
        "dest": "<%= yeoman.package %>",
        "privateKey": "~/gotnames.pem",
        "filename": "insite.crx",
        "options": {
          "maxBuffer": 500000 * 1024 //build extension with a weight up to 500MB
        }

      }
    },
    retire: {
      dist: {
        src: ['<%= yeoman.dist %>/{,*/}*.js'], /** Which js-files to scan. **/
        options: {
          jsOnly: true
        }
      }
    },
    connect: {
      server: {
        options: {
          port: 9001
        }
      }
    }
  });

  grunt.registerTask('build', [
    'clean:dist',
    'copy:dist',
    'concurrent:dist',
    'browserify:dist'
  ]);

  grunt.registerTask('package', [
    'clean:package',
    'prod',
    'crx:dist',
  ]);

  grunt.registerTask('prod', [
    'build',
    'coffee:prod',
    'retire:dist'
  ]);

  grunt.registerTask('default', [
    'build'
  ]);

  grunt.registerTask('dev', [
    'build',
    'connect',
    'watch:all'
  ]);
};
