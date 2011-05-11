Feature: Store and load small amount of data from one class
  In order to ensure basic functionality, ROD should
  allow to store and load data for one simple class.
  Background:
    Given the library works in development mode

  Scenario: class with one field
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string
    When database is created
    And I create a Caveman
    And his name is 'Fred'
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And the name of the first Caveman should be 'Fred'

    When database is created
    And I create a Caveman
    And her name is 'Wilma'
    And I store her in the database
    And I create another Caveman
    And his name is 'Barney'
    And I store him in the database
    Then there should be 2 Caveman(s)
    And the name of the first Caveman should be 'Wilma'
    And the name of the second Caveman should be 'Barney'
    And the third Caveman should not exist

  Scenario: class with every type of field
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string
    And a class Caveman has an age field of type integer
    And a class Caveman has an identifier field of type ulong
    And a class Caveman has a height field of type float
    When database is created
    And I create a Caveman
    And his name is 'Fred'
    And his age is '25'
    And his identifier is '111122223333'
    And his height is '1.86'
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And the name of the first Caveman should be 'Fred'
    And the age of the first Caveman should be '25'
    And the identifier of the first Caveman should be '111122223333'
    And the height of the first Caveman should be '1.86'

  Scenario: instance with string containing 0
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string
    When database is created
    And I create a Caveman
    And his name is 'Fred\0Fred'
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And the name of the first Caveman should be 'Fred\0Fred'

    When database is created
    And I create a Caveman
    And his name is 'Fred\0' multiplied 30000 times
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And the name of the first Caveman should be 'Fred\0' multiplied 30000 times

  Scenario: reading fields while objects are created
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string
    And a class Caveman has an age field of type integer
    And a class Caveman has an identifier field of type ulong
    And a class Caveman has a height field of type float
    When database is created
    And I create a Caveman
    And his name is 'Fred'
    And his age is '25'
    And his identifier is '111122223333'
    And his height is '1.86'
    Then his name should be 'Fred'
    And his age should be '25'
    And his identifier should be '111122223333'
    And his height should be '1.86'

  Scenario: referential integrity and simple indexing
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string
    When database is created
    And I create a Caveman
    And his name is 'Fred'
    And I store him in the database
    And I reopen database for reading
    Then the first Caveman should be identical with the first Caveman
    And the first Caveman should be equal with the instance

  Scenario: indexing of fields
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
    And his identifier is '111122223333'
    And his height is '1.86'
    And I store him in the database
    And I create another Caveman
    And his name is 'Barney'
    And his age is '26'
    And his identifier is '111122224444'
    And his height is '1.67'
    And I store him in the database
    And I create another Caveman
    And his name is 'Willma'
    And his age is '25'
    And his identifier is '111122225555'
    And his height is '1.67'
    And I store him in the database
    And I reopen database for reading
    Then there should be 3 Caveman(s)
    And there should be 1 Caveman with 'Fred' name
    And there should be 1 Caveman with 'Willma' name
    And there should be 1 Caveman with 'Barney' name
    And there should be 2 Caveman(s) with '25' age
    And there should be 1 Caveman with '26' age
    And there should be 1 Caveman with '111122223333' identifier
    And there should be 1 Caveman with '111122224444' identifier
    And there should be 1 Caveman with '111122225555' identifier
    And there should be 2 Caveman(s) with '1.67' height
    And there should be 1 Caveman with '1.86' height

  Scenario: model without instances
      A model without instances should be treated fine.
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string with flat index
    When database is created
    And I reopen database for reading
    Then there should be 0 Caveman(s)

  Scenario: model without instances with indexed field
      A model without instances but with indexed field should be treated fine.
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string with flat index
    And a class Automobile has a name field of type string with flat index
    When database is created
    And I create a Caveman
    And his name is 'Fred'
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And there should be 0 Automobile(s)
