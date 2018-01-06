# Wizard

## Technologies:
  * Elixir (http://elixir-lang.github.io/)
  * file_system (https://github.com/falood/file_system)

## Goals:
  * Fault-invincible
      * The program should be up 100% of the time and be able to restart failed components. It should gracefully handle all errors possible and keep on trying to keep the devices in sync until the computer to burnt to ash.
  * Asynchronous and concurrent
      * The system will rely on file-system watchers and spawn new threads for each new hash calculation or file transfer. The files should be able to transfer in parallel so that one big file doesn’t stop smaller ones from being transferred.
  * Real-time
      * Wizard should run 24/7 and keep computers as synchronized as the network allows. I should be able to write a document on one computer, save it, and pick up on another computer.
  * Transparent
      * The aggression of the sync should be adjustable so that it doesn’t monopolize resources. There should be a limit on the number of concurrent file-syncs and operations so that compiling and generating a lot of files really quickly doesn’t bog down the system as it struggles to sync up.
  * Configurable
      * There should be a master blacklist that tells the program what files to ignore when syncing. This file, and any other configurations should be hot-loadable so that the sync program never has to be restarted.

## Additional Features:
  * TLS encryption of sync data
  * Smart compression of sync data (detects whether the CPU or Network is the bottleneck, and tunes the compression ratio accordingly)

## Implementation Details:

###### Wizard.Index

This module is in charge of maintaining an index of all of watched files. It stores a map of files and their modified times. Upon initialization it will reindex all watched directories (because it could have missed changes during it's downtime) and it will subscribe to all further filesystem changes using the fs library.

This will be implemented in a GenServer. A handle_info callback will be used to respond to the filesystem subscription messages. This index is the first thing that is compared between synced folders. This module will also contain a function for computing the difference between two indices. If these indices match perfectly, job well done. If they are different, then a syncing process is spawned for all of the files that are contained in that difference and they are brought back into sync.

The index and a timestamp should be saved to disk on exit, so that deleted files can be tracked. If a file is deleted while wizard is not running, on the next start, the missing file will be noticed. If the file was deleted more recently than all other remote versions were modified, it should be safe to delete.

###### Misc Notes:
  * If files are different, compute hashes block by block (1024 bytes) and for all differing blocks in the old file, replace them with the new blocks. This will be a bit tricky, so here is a reference: [Rsync Overview](http://tutorials.jenkov.com/rsync/overview.html).
  * When files are deleted, they should be just moved to the trash, not fully deleted. After a month or so, it should be safe to delete the files completely from the trash. This is important because fully deleting files on all machines means no chance of a backup. Wizard wouldn't help recover from a nasty rm command if it didn't save deleted files for a little while.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `wizard` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:wizard, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/wizard](https://hexdocs.pm/wizard).
