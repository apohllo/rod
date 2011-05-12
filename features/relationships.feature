Feature: relationships between different classes
  In order to ensure relationship storage, ROD should
  allow to store and load data having connections with other data
  Background:
    Given the library works in development mode

  Scenario: two classes with has one relationship
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string
    And a class Automobile has a name field of type string
    And a class Caveman has one automobile
    When the database is created
    And I create an Automobile
    And its name is 'Prehistoric car'
    And I store it in the database
    And I create a Caveman
    And his name is 'Fred'
    And his automobile is the first Automobile created
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And there should be 1 Automobile
    And the name of the first Caveman should be 'Fred'
    And the name of the first Automobile should be 'Prehistoric car'
    And the automobile of the first Caveman should be equal to the first Automobile

    # Should store nil
    When the database is created
    And I create a Caveman
    And his name is 'Fred'
    And his automobile is nil
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And the name of the first Caveman should be 'Fred'
    And the automobile of the first Caveman should be nil

  Scenario: two classes with has many relationship
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string
    And a class Automobile has a name field of type string
    And a class Caveman has many automobiles
    When the database is created
    And I create an Automobile
    And its name is 'Prehistoric car'
    And I store it in the database
    And I create another Automobile
    And its name is 'Modern car'
    And I store it in the database
    And I create a Caveman
    And his name is 'Fred'
    And his automobiles contain the first Automobile created
    And his automobiles contain the second Automobile created
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And there should be 2 Automobile(s)
    And the name of the first Caveman should be 'Fred'
    And the name of the first Automobile should be 'Prehistoric car'
    And the name of the second Automobile should be 'Modern car'
    And the first Caveman should have 2 automobiles
    And the first of automobiles of the first Caveman should be equal to the first Automobile
    And the second of automobiles of the first Caveman should be equal to the second Automobile

    # Should store in any order
    When the database is created
    And I create an Automobile
    And its name is 'Prehistoric car'
    And I create another Automobile
    And its name is 'Modern car'
    And I create a Caveman
    And his name is 'Fred'
    And his automobiles contain the first Automobile created
    And his automobiles contain the second Automobile created
    And I store the first Caveman in the database
    And I store the first Automobile in the database
    And I store the second Automobile in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And there should be 2 Automobile(s)
    And the first Caveman should have 2 automobiles

    # Should store nil
    When the database is created
    And I create an Automobile
    And its name is 'Prehistoric car'
    And I create another Automobile
    And its name is 'Modern car'
    And I create a Caveman
    And his name is 'Fred'
    And his automobiles contain the first Automobile created
    And his automobiles contain nil
    And his automobiles contain the second Automobile created
    And I store the first Caveman in the database
    And I store the first Automobile in the database
    And I store the second Automobile in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And there should be 2 Automobile(s)
    And the first Caveman should have 3 automobiles
    And the first of automobiles of the first Caveman should be equal to the first Automobile
    And the second of automobiles of the first Caveman should be nil
    And the third of automobiles of the first Caveman should be equal to the second Automobile

  Scenario: three classes with has one polymorphic association
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string
    And a class Caveman has one polymorphic item
    And a class Automobile has a name field of type string
    And a class Dog has a nickname field of type string
    When the database is created
    And I create an Automobile
    And its name is 'Prehistoric car'
    And I store it in the database
    And I create a Dog
    And its nickname is 'Snoopy'
    And I store it in the database
    And I create a Caveman
    And his name is 'Fred'
    And his item is the first Automobile created
    And I store him in the database
    And I create another Caveman
    And her name is 'Willma'
    And her item is the first Dog created
    And I store her in the database
    And I reopen database for reading
    Then there should be 2 Caveman(s)
    And there should be 1 Automobile
    And there should be 1 Dog
    And the item of the first Caveman should be equal to the first Automobile
    And the item of the second Caveman should be equal to the first Dog

    # should store nil
    When the database is created
    And I create a Caveman
    And his name is 'Fred'
    And his item is nil
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And the name of the first Caveman should be 'Fred'
    And the item of the first Caveman should be nil

  Scenario: three classes with has many polymorphic association
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string
    And a class Caveman has many polymorphic items
    And a class Automobile has a name field of type string
    And a class Dog has a nickname field of type string
    When the database is created
    And I create an Automobile
    And its name is 'Prehistoric car'
    And I store it in the database
    And I create a Dog
    And its nickname is 'Snoopy'
    And I store it in the database
    And I create a Caveman
    And his name is 'Fred'
    And his items contain the first Automobile created
    And his items contain the first Dog created
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And there should be 1 Automobile
    And there should be 1 Dog
    And the first Caveman should have 2 items
    And the first of items of the first Caveman should be equal to the first Automobile
    And the second of items of the first Caveman should be equal to the first Dog

    # should store nil
    When the database is created
    And I create an Automobile
    And its name is 'Prehistoric car'
    And I store it in the database
    And I create a Dog
    And its nickname is 'Snoopy'
    And I store it in the database
    And I create a Caveman
    And his name is 'Fred'
    And his items contain the first Automobile created
    And his items contain nil
    And his items contain the first Dog created
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And there should be 1 Automobile
    And there should be 1 Dog
    And the first Caveman should have 3 items
    And the first of items of the first Caveman should be equal to the first Automobile
    And the second of items of the first Caveman should be nil
    And the third of items of the first Caveman should be equal to the first Dog
