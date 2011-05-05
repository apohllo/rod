Feature: relationships between different classes
  In order to ensure relationship storage, ROD should
  allow to store and load data having connections with other data
  Background:
    Given the library works in development mode

  Scenario: two classes with has one relationship
    Given the class space is cleared
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

  Scenario: two classes with has many relationship
    Given the class space is cleared
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
