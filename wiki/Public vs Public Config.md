# The Difference Between `module.public` and `module.config.public`

You may be asking yourself - why do I need two public and private tables? Can't I just use one? Which one should I use on which occasion?

To put it simply, this is your answer:
Entries in the `config` tables like `config.public` and `config.private` are for *static data*, or things that should only change once.
- `config.public` should be used for exposing entries to be edited by the user
- `config.private` should be used for things the developer may want to tweak that will change the behaviour of the module.
It cannot be accessed by the user or anyone else, and is only for the developer, remember that.

Entries outside of the `config` table, like `public` and `private`, are for *dynamic data*, ie. things that change over time or change the behaviour
of a module over time.
- `public` should be used for data that you don't want the user to change, but you want other modules to change and be able to read in order to alter
the behaviour of the neorg environment at runtime. This table can contain both other tables and/or functions, but you will primarily see public functions here.
- `private` is the opposite of public. Here you can store variables for tracking internal data you don't want anyone else to see, or for functions
you don't want others to access but are convenient for you to have.

### Still got questions?
Ask away on the [discord](https://discord.gg/T6EgTAX7ht), I'm always happy to help!
