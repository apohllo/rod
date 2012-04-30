Feature: Portability model
    The database should be portable across systems with different
    byte order and procesor register length.
  Background:
    Given the library works in development mode

  Scenario: this scenario is used to generate the data used in portability tests
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string
    And a class Caveman has an age field of type integer
    And a class Caveman has an identifier field of type ulong
    And a class Caveman has a height field of type float
    And a class Caveman has a account_balance field of type float
    And a class Automobile has a name field of type string
    And a class Caveman has one automobile
    And a class Dog has a nickname field of type string
    And a class Caveman has many dogs
    When database is created
    And I create an Automobile
    And its name is 'Prehistoric car'
    And I store it in the database
    And I create a Dog
    And its nickname is 'Snoopy'
    And I store it in the database
    And I create a Caveman
    And his name is 'Fred'
    And his age is '25'
    And his identifier is '111222333'
    And his height is '1.86'
    And his account_balance is '-0.00000001'
    And his automobile is the first Automobile created
    And his dogs contain the first Dog created
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And there should be 1 Dog
    And there should be 1 Automobile
    And the name of the first Caveman should be 'Fred'
    And the age of the first Caveman should be '25'
    And the identifier of the first Caveman should be '111222333'
    And the height of the first Caveman should be '1.86'
    And the account_balance of the first Caveman should be '-0.00000001'
    And the automobile of the first Caveman should be equal to the first Automobile
    And the first of dogs of the first Caveman should be equal to the first Dog

  @wip
  Scenario: class with every type of field and association
      Rod should allow to read data created on little endian 64-bit system
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string
    And a class Caveman has an age field of type integer
    And a class Caveman has an identifier field of type ulong
    And a class Caveman has a height field of type float
    And a class Caveman has a account_balance field of type float
    And a class Automobile has a name field of type string
    And a class Caveman has one automobile
    And a class Dog has a nickname field of type string
    And a class Caveman has many dogs
    When I open the database for reading in data/portability
    Then there should be 1 Caveman
    And there should be 1 Dog
    And there should be 1 Automobile
    And the name of the first Caveman should be 'Fred'
    And the age of the first Caveman should be '25'
    And the identifier of the first Caveman should be '111222333'
    And the height of the first Caveman should be '1.86'
    And the account_balance of the first Caveman should be '-0.00000001'
    And the automobile of the first Caveman should be equal to the first Automobile persisted
    And the first of dogs of the first Caveman should be equal to the first Dog persisted
