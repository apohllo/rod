Feature: Access to objects with indexed fields
  ROD allows for accessing objects via fields with indices.

  Background:
    Given the library works in development mode

  Scenario: simple indexing
      Rod should allow to access objects via values of their fields,
      for which indices were built.
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string with flat index
    And a class Caveman has an age field of type integer with flat index
    And a class Caveman has an identifier field of type ulong with flat index
    And a class Caveman has a height field of type float with flat index
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
    And I store him in the database
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

  Scenario: indexing of fields with different DBs for the same model
    The contents of indices should be fulshed when the database is reopened.
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string with flat index
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
    And database is created in location2
    And I create a Caveman
    And his name is 'Wilma'
    And I store him in the database
    And I create another Caveman
    And his name is 'Wilma'
    And I store him in the database
    And I create another Caveman
    And his name is 'Wilma'
    And I store him in the database
    And I reopen database for reading in location2
    Then there should be 3 Caveman(s)
    And there should be 3 Caveman(s) with 'Wilma' name
    And there should be 0 Caveman(s) with 'Fred' name
    And some Caveman with 'Wilma' name should be equal to the first Caveman

  Scenario: indexing of particular values
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string with flat index
    And a class Caveman has a surname field of type string with flat index
    And a class Caveman has a login field of type string with flat index
    And a class Caveman has an age field of type integer with flat index
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
    And there should be 2 Caveman with '' name
    And there should be 2 Caveman(s) with '' surname

  Scenario: multiple object with indexed fields
      The database should properly store thausands of objects with some indexed fields.
    Given the class space is cleared
    And the model is connected with the default database
    And a class User has a name field of type string with flat index
    And a class User has a surname field of type string with flat index
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

  Scenario: reading indices when the DB is created
      It should be possible to access indices for objects which are already
      stored in the DB.
    Given the class space is cleared
    And the model is connected with the default database
    And a class User has a name field of type string with flat index
    When database is created
    And I create a User
    And his name is 'John'
    And I store him in the database
    Then there should exist a User with 'John' name
    And there should be 1 User with 'John' name
