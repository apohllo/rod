Feature: Access to objects with hash indices.
    ROD allows for accessing objects via fields with hash indices,
    which are useful for indices with millions of keys.
    These are split accross multiple files for faster load-time.

  Scenario: indexing with hash index
      Rod should allow to access objects via values of their fields,
      for which indices were built.
    Given the class space is cleared
    And the default database is initialized
    And the following class is defined:
      """
      class Caveman
        include Rod.resource

        attribute :name, String, :index => :hash
        attribute :age, Integer, :index => :hash
        attribute :identifier, Integer, :index => :hash
        attribute :height, Float, :index => :hash
      end
      """
    When database is created
    And I create a Caveman
    And his name is 'Fred'
    And his age is '25'
    And his identifier is '111222333'
    And his height is '1.86'
    And I store him in the database
    And I create another Caveman
    And his name is 'Barney'
    And his age is '26'
    And his identifier is '111222444'
    And his height is '1.67'
    And I store him in the database
    And I create another Caveman
    And his name is 'Wilma'
    And his age is '25'
    And his identifier is '111222555'
    And his height is '1.67'
    And I store her in the database
    And I reopen database for reading
    Then there should be 3 Caveman(s)
    And there should be 1 Caveman with 'Fred' name
    And there should be 1 Caveman with 'Wilma' name
    And there should be 1 Caveman with 'Barney' name
    And there should be 2 Caveman(s) with '25' age
    And there should be 1 Caveman with '26' age
    And there should be 1 Caveman with '111222333' identifier
    And there should be 1 Caveman with '111222444' identifier
    And there should be 1 Caveman with '111222555' identifier
    And there should be 2 Caveman(s) with '1.67' height
    And there should be 1 Caveman with '1.86' height
    And some Caveman with 'Fred' name should be equal to the first Caveman
    And some Caveman with 'Barney' name should be equal to the second Caveman
    And some Caveman with 'Wilma' name should be equal to the third Caveman
    And the first Caveman with 'Fred' name should be equal to the first Caveman
    And the first Caveman with 'Barney' name should be equal to the second Caveman
    And the first Caveman with 'Wilma' name should be equal to the third Caveman

    # Test re-creation of the database
    When database is created
    And I create a Caveman
    And his name is 'Fred'
    And I store him in the database
    And I create another Caveman
    And his name is 'Barney'
    And I store him in the database
    And I create another Caveman
    And her name is 'Wilma'
    And I store her in the database
    And I reopen database for reading
    Then there should be 3 Caveman(s)
    And there should be 1 Caveman with 'Fred' name
    And there should be 1 Caveman with 'Wilma' name
    And there should be 1 Caveman with 'Barney' name
    And some Caveman with 'Fred' name should be equal to the first Caveman
    And some Caveman with 'Barney' name should be equal to the second Caveman
    And some Caveman with 'Wilma' name should be equal to the third Caveman
    And the first Caveman with 'Fred' name should be equal to the first Caveman
    And the first Caveman with 'Barney' name should be equal to the second Caveman
    And the first Caveman with 'Wilma' name should be equal to the third Caveman

  Scenario: extending the DB when hash index is used
      Rod should allow to extend the DB when the hash index is used.
      The index should be properly updated.
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string with hash index
    When database is created
    And I create a Caveman
    And his name is 'Fred'
    And I store him in the database
    And I create another Caveman
    And his name is 'Barney'
    And I store him in the database
    And I reopen database
    And I create another Caveman
    And her name is 'Wilma'
    And I store her in the database
    And I create another Caveman
    And his name is 'Fred'
    And I store him in the database
    And I reopen database for reading
    Then there should be 4 Caveman(s)
    And there should be 1 Caveman with 'Wilma' name
    And there should be 2 Caveman(s) with 'Fred' name
    And there should be 1 Caveman with 'Barney' name
    And some Caveman with 'Fred' name should be equal to the first Caveman
    And some Caveman with 'Barney' name should be equal to the second Caveman
    And some Caveman with 'Wilma' name should be equal to the third Caveman
    And the first Caveman with 'Barney' name should be equal to the second Caveman
    And the first Caveman with 'Wilma' name should be equal to the third Caveman

  Scenario: indexing of fields with different DBs for the same model with hash index
    The contents of indices should be fulshed when the database is reopened.
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string with hash index
    When database is created
    And I create a Caveman
    And his name is 'Fred'
    And I store him in the database
    And I create another Caveman
    And his name is 'Fred'
    And I store him in the database
    And I create another Caveman
    And his name is 'Fred'
    And I store him in the database
    And I reopen database for reading
    And I access the Caveman name index
    And database is created in tmp/location2
    And I create a Caveman
    And his name is 'Wilma'
    And I store him in the database
    And I create another Caveman
    And his name is 'Wilma'
    And I store him in the database
    And I create another Caveman
    And his name is 'Wilma'
    And I store him in the database
    And I reopen database for reading in tmp/location2
    Then there should be 3 Caveman(s)
    And there should be 3 Caveman(s) with 'Wilma' name
    And there should be 0 Caveman(s) with 'Fred' name
    And some Caveman with 'Wilma' name should be equal to the first Caveman

  Scenario: indexing of particular values with hash index
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string with hash index
    And a class Caveman has a surname field of type string with hash index
    And a class Caveman has a login field of type string with hash index
    And a class Caveman has an age field of type integer with hash index
    When database is created
    And I create and store the following Caveman(s):
      | name | surname | login | age  |
      | John | Smith   | john  | 12   |
      | Lara | Croft   | lara  | 23   |
      | Adam | Parker  | adam  | 12   |
      | Adam |         | noob1 | 33   |
      |      |         | noob2 | -1   |
      |      | Adam    | noob1 | 33   |
    And I reopen database for reading
    Then there should be 6 Caveman(s)
    And there should be 1 Caveman with 'John' name
    And there should be 2 Caveman(s) with 'Adam' name
    And there should be 2 Caveman(s) with '12' age
    And there should be 1 Caveman with '-1' age
    And there should be 2 Caveman(s) with '' name
    And there should be 2 Caveman(s) with '' surname

  Scenario: multiple objects with indexed fields with hash index
      The database should properly store thausands of objects with some indexed fields.
    Given the class space is cleared
    And the model is connected with the default database
    And a class User has a name field of type string with hash index
    And a class User has a surname field of type string with hash index
    And a class User has an age field of type integer
    When database is created
    And I create a User
    And his name is 'John'
    And his surname is 'Smith'
    And his age is '21'
    And I store him in the database 1000 times
    And I create a User
    And her name is 'Lara'
    And her surname is 'Croft'
    And her age is '23'
    And I store her in the database 1000 times
    And I reopen database for reading
    Then there should be 2000 User(s)
    Then there should be 1000 User(s) with 'John' name
    Then there should be 1000 User(s) with 'Smith' surname
    Then there should be 1000 User(s) with 'Lara' name
    Then there should be 1000 User(s) with 'Croft' surname
    And some User with 'John' name should be equal to the first User

  Scenario: iterating over the index key-values pairs
      It should be possible to iterate over the keys of a index.
    Given the class space is cleared
    And the model is connected with the default database
    And a class User has a name field of type string with hash index
    When database is created
    And I create a User
    And his name is 'John'
    And I store him in the database
    And I create a User
    And her name is 'Lara'
    And I store her in the database
    And I create a User
    And her name is 'Lara'
    And I store her in the database
    And I create a User
    And her name is 'Pipi'
    And I store her in the database
    And I reopen the database for reading
    And I iterate over the name index of User
    Then there should be 1 User with 'John' name in the iteration results
    And there should be 2 User(s) with 'Lara' name in the iteration results
    And there should be 1 User with 'Pipi' name in the iteration results
    And there should be 0 User(s) with 'Fred' name in the iteration results

  Scenario: indexing with empty database
      Rod should behave well when there is an index on a model while
      the database is created and nothing is stored in it.
    Given the class space is cleared
    And the model is connected with the default database
    And a class User has a name field of type string with hash index
    When database is created
    And I reopen the database for reading
    Then there should be 0 User(s)
