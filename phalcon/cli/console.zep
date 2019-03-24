
/**
 * This file is part of the Phalcon Framework.
 *
 * (c) Phalcon Team <team@phalconphp.com>
 *
 * For the full copyright and license information, please view the LICENSE.txt
 * file that was distributed with this source code.
 */

namespace Phalcon\Cli;

use Phalcon\Application as BaseApplication;
use Phalcon\Cli\Router\Route;
use Phalcon\Cli\Console\Exception;
use Phalcon\DiInterface;
use Phalcon\Events\ManagerInterface;

/**
 * Phalcon\Cli\Console
 *
 * This component allows to create CLI applications using Phalcon
 */
class Console extends BaseApplication
{

    protected arguments = [];

    protected options = [];

    /**
     * Handle the whole command-line tasks
     */
    public function handle(array arguments = null)
    {
        var container, router, eventsManager,
            moduleName, modules, module, path, className,
            moduleObject, dispatcher, task;

        let container = this->container;
        if typeof container != "object" {
            throw new Exception("A dependency injection object is required to access internal services");
        }

        let eventsManager = <ManagerInterface> this->eventsManager;

        /**
         * Call boot event, this allow the developer to perform initialization actions
         */
        if typeof eventsManager == "object" {
            if eventsManager->fire("console:boot", this) === false {
                return false;
            }
        }

        let router = <Router> container->getShared("router");

        if !count(arguments) && this->arguments {
            router->handle(this->arguments);
        } else {
            router->handle(arguments);
        }

        /**
         * If the router doesn't return a valid module we use the default module
         */
        let moduleName = router->getModuleName();
        if !moduleName {
            let moduleName = this->defaultModule;
        }

        if moduleName {

            if typeof eventsManager == "object" {
                if eventsManager->fire("console:beforeStartModule", this, moduleName) === false {
                    return false;
                }
            }

            let modules = this->modules;
            if !isset modules[moduleName] {
                throw new Exception("Module '" . moduleName . "' isn't registered in the console container");
            }

            let module = modules[moduleName];
            if typeof module != "array" {
                throw new Exception("Invalid module definition path");
            }

            if !fetch className, module["className"] {
                let className = "Module";
            }

            if fetch path, module["path"] {
                if !class_exists(className, false) {
                    if !file_exists(path) {
                        throw new Exception("Module definition path '" . path . "' doesn't exist");
                    }

                    require path;
                }
            }

            let moduleObject = container->get(className);

            moduleObject->registerAutoloaders();
            moduleObject->registerServices(container);

            if typeof eventsManager == "object" {
                if eventsManager->fire("console:afterStartModule", this, moduleObject) === false {
                    return false;
                }
            }

        }

        let dispatcher = <\Phalcon\Cli\Dispatcher> container->getShared("dispatcher");

        dispatcher->setModuleName(router->getModuleName());
        dispatcher->setTaskName(router->getTaskName());
        dispatcher->setActionName(router->getActionName());
        dispatcher->setParams(router->getParams());
        dispatcher->setOptions(this->options);

        if typeof eventsManager == "object" {
            if eventsManager->fire("console:beforeHandleTask", this, dispatcher) === false {
                return false;
            }
        }

        let task = dispatcher->dispatch();

        if typeof eventsManager == "object" {
            eventsManager->fire("console:afterHandleTask", this, task);
        }

        return task;
    }

    /**
     * Set an specific argument
     */
    public function setArgument(array! arguments = null, bool! str = true, bool! shift = true) -> <Console>
    {
        var arg, pos, args, opts, handleArgs;

        let args = [],
            opts = [],
            handleArgs = [];

        if shift && count(arguments) {
            array_shift(arguments);
        }

        for arg in arguments {
            if typeof arg == "string" {
                if strncmp(arg, "--", 2) == 0 {
                    let pos = strpos(arg, "=");
                    if pos {
                        let opts[trim(substr(arg, 2, pos - 2))] = trim(substr(arg, pos + 1));
                    } else {
                        let opts[trim(substr(arg, 2))] = true;
                    }
                } else {
                    if strncmp(arg, "-", 1) == 0 {
                        let opts[substr(arg, 1)] = true;
                    } else {
                        let args[] = arg;
                    }
                }
            } else {
                let args[] = arg;
            }
        }

        if str {
            let this->arguments = implode(Route::getDelimiter(), args);
        } else {
            if count(args) {
                let handleArgs["task"] = array_shift(args);
            }
            if count(args) {
                let handleArgs["action"] = array_shift(args);
            }
            if count(args) {
                let handleArgs = array_merge(handleArgs, args);
            }
            let this->arguments = handleArgs;
        }

        let this->options = opts;

        return this;
    }
}
